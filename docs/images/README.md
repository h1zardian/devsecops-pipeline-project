# Demonstration image replacements

The four PNG files in this directory are explicit placeholders. Replace them
with sanitized screenshots from a short-lived deployment while keeping these
exact filenames so the links in the root README continue to work:

| Filename | Capture | Include | Exclude |
| --- | --- | --- | --- |
| `app-endpoint.png` | Public Django AWS endpoint | Browser address bar and rendered landing page | Credentials, cookies, or personal data |
| `argocd-applications.png` | Argo CD Applications view | All platform applications in `Healthy` and `Synced` state | Admin password, tokens, or repository credentials |
| `grafana-dashboard.png` | Provisioned DevSecOps dashboard | Healthy panels with a useful time range | Login credentials or unrelated account data |
| `github-actions.png` | Repository Actions view | Successful application, Terraform, and Kubernetes workflows | Browser extensions or unrelated repositories |

Use a consistent 16:9 crop, preferably 1280×720 or larger. Verify each image
after committing it through GitHub's rendered README. The placeholders make no
claim that the pictured interfaces are currently live.
