#!/usr/bin/env bash

set -e

_usage="Usage: $0 [--version (antrea release version)] [--help|-h]
Generate a new Antrea YAML manifest template from a Antrea released version.
        --version (antrea release version) Example: $0 v0.9.3
        --help, -h                      Print this message and exit
"

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --version)
    ANTREA_VERSION="$2"
    shift 2
    ;;
    -h|--help)
    print_usage
    exit 0
    ;;
    *)    # unknown option
    echo "Unknown option $1"
    exit 1
    ;;
esac
done

NEW_DOC="antrea.yml.new"
TMP_DOC="antrea.yml.tmp"
TMP_ANTREA_CONFIGMAP_DOC="antrea_configmap.yml.tmp"
NO_USED_PLACEHOLDER='NO_USED_PLACEHOLDER'

ANTREA_AGENT_CONFIG_RENDER_KEY='{{.AntreaAgentConfig | indent 4}}'
ANTREA_AGENT_CONFIG_RENDER_KEY_PLACE_HOLDER="ANTREA_AGENT_CONFIG_RENDER_KEY_PLACE_HOLDER"

ANTREA_CNI_CONFIG_RENDER_KEY='{{.AntreaCNIConfig | indent 4}}'
ANTREA_CNI_CONFIG_RENDER_KEY_PLACE_HOLDER="ANTREA_CNI_CONFIG_RENDER_KEY_PLACE_HOLDER"

ANTREA_CONTROLLER_CONFIG_RENDER_KEY='{{.AntreaControllerConfig | indent 4}}'
ANTREA_CONTROLLER_CONFIG_RENDER_KEY_PLACE_HOLDER="ANTREA_CONTROLLER_CONFIG_RENDER_KEY_PLACE_HOLDER"

ANTREA_IMAGE_RENDER_KEY="{{.AntreaImage}}"

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

pushd $THIS_DIR

wget -c "https://github.com/vmware-tanzu/antrea/releases/download/$ANTREA_VERSION/antrea.yml" -O $NEW_DOC
# Get Length
num=$(yq r $NEW_DOC  -d'*' -c --length)
rm -f $TMP_DOC
rm -f $TMP_ANTREA_CONFIGMAP_DOC
# Iterate yaml document.
for ((i=0;i<num;i++)); do
    is_antrea_configmap=$(yq r $NEW_DOC  -d "$i" -c | yq r - '(metadata.name==antrea-config*)')
    if [[ ! -z $is_antrea_configmap ]]
    then
        echo "$is_antrea_configmap" > $TMP_ANTREA_CONFIGMAP_DOC
        # PLACE_HOLDER="${ANTREA_AGENT_CONFIG_RENDER_KEY_PLACE_HOLDER}\n${NO_USED_PLACEHOLDER}"
        PLACE_HOLDER=$(echo -e "${ANTREA_AGENT_CONFIG_RENDER_KEY_PLACE_HOLDER}\n${NO_USED_PLACEHOLDER}")
        yq w  --inplace $TMP_ANTREA_CONFIGMAP_DOC  'data."antrea-agent.conf"'  "$PLACE_HOLDER"
        PLACE_HOLDER=$(echo -e "${ANTREA_CNI_CONFIG_RENDER_KEY_PLACE_HOLDER}\n${NO_USED_PLACEHOLDER}")
        yq w  --inplace $TMP_ANTREA_CONFIGMAP_DOC 'data."antrea-cni.conflist"'  "$PLACE_HOLDER"
        PLACE_HOLDER=$(echo -e "${ANTREA_CONTROLLER_CONFIG_RENDER_KEY_PLACE_HOLDER}\n${NO_USED_PLACEHOLDER}")
        yq w  --inplace $TMP_ANTREA_CONFIGMAP_DOC 'data."antrea-controller.conf"'  "$PLACE_HOLDER"
        echo "---" >> $TMP_DOC
        cat $TMP_ANTREA_CONFIGMAP_DOC >> $TMP_DOC
    else
        echo "---" >> $TMP_DOC
        yq r $NEW_DOC  -d "*" -c  | yq r - "[$i]" >> $TMP_DOC
    fi
done

sed -i "/${NO_USED_PLACEHOLDER}/d" $TMP_DOC
sed -i "s/.*${ANTREA_AGENT_CONFIG_RENDER_KEY_PLACE_HOLDER}/${ANTREA_AGENT_CONFIG_RENDER_KEY}/" $TMP_DOC
sed -i "s/.*${ANTREA_CNI_CONFIG_RENDER_KEY_PLACE_HOLDER}/${ANTREA_CNI_CONFIG_RENDER_KEY}/" $TMP_DOC
sed -i "s/.*${ANTREA_CONTROLLER_CONFIG_RENDER_KEY_PLACE_HOLDER}/${ANTREA_CONTROLLER_CONFIG_RENDER_KEY}/" $TMP_DOC
sed -i "s/image.*/image: ${ANTREA_IMAGE_RENDER_KEY}/" $TMP_DOC

rm -f $TMP_ANTREA_CONFIGMAP_DOC
rm -f $NEW_DOC
mv $TMP_DOC ../../manifest/antrea.yml
# TODO: Update default Antrea image version

popd > /dev/null
