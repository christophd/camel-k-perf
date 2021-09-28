package cli

import (
	"fmt"

	project "github.com/openshift/api/project/v1"
	"github.com/spf13/cobra"
	ctrl "sigs.k8s.io/controller-runtime/pkg/client"
)

func newCmdCleanup(rootCmdOptions *RootCmdOptions) *cobra.Command {
	options := CleanupCmdOptions{
		RootCmdOptions: rootCmdOptions,
	}
	cmd := cobra.Command{
		Use:   "cleanup",
		Short: "Delete all generated data.",
		RunE:  options.run,
	}

	return &cmd
}

type CleanupCmdOptions struct {
	*RootCmdOptions
}

func (o *CleanupCmdOptions) run(cmd *cobra.Command, _ []string) error {
	projects := project.ProjectList{}
	if err := o.Client.List(o.Ctx, &projects, ctrl.MatchingLabels{"perf.generated": "true"}); err != nil {
		return err
	}
	for _, p := range projects.Items {
		if err := o.Client.Delete(o.Ctx, &p); err != nil {
			fmt.Printf("Error deleting project %q\n", p.Name)
			return err
		}
		fmt.Printf("Project %q deleted\n", p.Name)
	}
	return nil
}
