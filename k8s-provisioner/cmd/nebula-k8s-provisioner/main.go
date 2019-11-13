package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/puppetlabs/horsehead/v2/workdir"
	"github.com/puppetlabs/nebula-sdk/pkg/log"
	outputsclient "github.com/puppetlabs/nebula-sdk/pkg/outputs"
	"github.com/puppetlabs/nebula-sdk/pkg/taskutil"
	"github.com/puppetlabs/nebula-steps/k8s-provisioner/pkg/provisioning"
	"github.com/puppetlabs/nebula-steps/k8s-provisioner/pkg/provisioning/models"
)

func main() {
	specURL := flag.String("spec-url", os.Getenv(taskutil.SpecURLEnvName), "url to fetch the spec from")
	workDir := flag.String("work-dir", "", "a working directory to store temporary and generated files")

	flag.Parse()

	log.Info("provisioning k8s cluster")

	planOpts := taskutil.DefaultPlanOptions{SpecURL: *specURL}

	var spec models.K8sProvisionerSpec
	if err := taskutil.PopulateSpecFromDefaultPlan(&spec, planOpts); err != nil {
		log.FatalE(err)
	}

	var wd *workdir.WorkDir

	{
		var err error
		if *workDir != "" {
			// we will NOT be calling wd.Cleanup() when using a directory passed in by a flag. This is a disaster waiting to happen.
			wd, err = workdir.New(*workDir, workdir.Options{})
			if err != nil {
				log.FatalE(err)
			}
		} else {
			ns := workdir.NewNamespace([]string{"nebula", "task-k8s-provisioner"})
			wd, err = ns.New(workdir.DirTypeCache, workdir.Options{})
			if err != nil {
				log.FatalE(err)
			}
			// we can reliably defer the cleanup of this directory. we have used our own namespace.
			defer wd.Cleanup()
		}

	}

	outputs, err := outputsclient.NewDefaultOutputsClientFromNebulaEnv()
	if err != nil {
		log.FatalE(err)
	}

	managerCfg := provisioning.K8sClusterManagerConfig{
		Spec:          &spec,
		Workdir:       wd.Path,
		OutputsClient: outputs,
	}

	manager, err := provisioning.NewK8sClusterManagerFromSpec(managerCfg)
	if err != nil {
		log.FatalE(err)
	}

	// TODO: we need to figure out how to better provision a cluster and report readiness.
	// Currently we set a massively long timeout, which is a non-ideal solution.
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute*10)
	defer cancel()

	cluster, err := manager.Synchronize(ctx)
	if err != nil {
		log.FatalE(err)
	}

	log.Info(fmt.Sprintf("%v", cluster))
}
