/* Copyright © 2020 VMware, Inc. All Rights Reserved.
   SPDX-License-Identifier: Apache-2.0 */

package status

import (
	"context"
	"reflect"
	"time"

	configv1 "github.com/openshift/api/config/v1"
	"github.com/openshift/cluster-network-operator/pkg/controller/statusmanager"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"

	operatorv1 "github.com/ruicao93/antrea-operator/pkg/apis/operator/v1"
	"github.com/ruicao93/antrea-operator/pkg/controller/sharedinfo"
	operatortypes "github.com/ruicao93/antrea-operator/pkg/types"
)

var log = logf.Log.WithName("controller_status")

// The periodic resync interval.
var ResyncPeriod = 2 * time.Minute

// Add creates a new Status Controller and adds it to the Manager. The Manager will set fields on the Controller
// and Start it when the Manager is Started.
func Add(mgr manager.Manager, status *statusmanager.StatusManager, sharedInfo *sharedinfo.SharedInfo) error {
	return add(mgr, newReconciler(mgr, status, sharedInfo))
}

// newReconciler returns a new reconcile.Reconciler
func newReconciler(mgr manager.Manager, status *statusmanager.StatusManager, sharedInfo *sharedinfo.SharedInfo) reconcile.Reconciler {
	return &ReconcileStatus{client: mgr.GetClient(), scheme: mgr.GetScheme(), status: status, sharedInfo: sharedInfo}
}

// add adds a new Controller to mgr with r as the reconcile.Reconciler
func add(mgr manager.Manager, r reconcile.Reconciler) error {
	// Create a new controller
	c, err := controller.New("status-controller", mgr, controller.Options{Reconciler: r})
	if err != nil {
		return err
	}

	// Watch for changes to status of cluster operator object
	err = c.Watch(&source.Kind{Type: &configv1.ClusterOperator{}}, &handler.EnqueueRequestForObject{})
	if err != nil {
		return err
	}

	return nil
}

// blank assignment to verify that ReconcileStatus implements reconcile.Reconciler
var _ reconcile.Reconciler = &ReconcileStatus{}

// ReconcileStatus reconciles a ClusterOperator object
type ReconcileStatus struct {
	client     client.Client
	scheme     *runtime.Scheme
	status     *statusmanager.StatusManager
	sharedInfo *sharedinfo.SharedInfo
}

// Reconcile sync the AntreaInstallStatus from antrea ClusterOperator.Status
func (r *ReconcileStatus) Reconcile(request reconcile.Request) (reconcile.Result, error) {
	reqLogger := log.WithValues("Request.Namespace", request.Namespace, "Request.Name", request.Name)

	if request.Name != operatortypes.AntreaClusterOperatorName {
		return reconcile.Result{}, nil
	}

	reqLogger.Info("Reconciling status update")
	if err := r.SyncAntreaInstallStatus(); err != nil {
		log.Error(err, "Failed to sync the status of AntreaInstall")
		if apierrors.IsNotFound(err) {
			return reconcile.Result{}, nil
		}
		return reconcile.Result{Requeue: true}, err
	}

	return reconcile.Result{RequeueAfter: ResyncPeriod}, nil
}

func (r *ReconcileStatus) SyncAntreaInstallStatus() error {
	co := &configv1.ClusterOperator{}
	err := r.client.Get(context.TODO(), types.NamespacedName{Name: operatortypes.AntreaClusterOperatorName}, co)
	if err != nil {
		return err
	}

	antreaInstall := &operatorv1.AntreaInstall{}
	err = r.client.Get(context.TODO(), types.NamespacedName{Namespace: operatortypes.OperatorNameSpace, Name: operatortypes.OperatorConfigName}, antreaInstall)
	if err != nil {
		return err
	}

	if reflect.DeepEqual(co.Status.Conditions, antreaInstall.Status.Conditions) {
		return nil
	}
	coStatus := co.Status.DeepCopy()
	antreaInstall.Status.Conditions = coStatus.Conditions
	return r.client.Status().Update(context.TODO(), antreaInstall)
}
