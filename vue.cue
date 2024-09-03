package deploy

import (
	"strings"
	"tool/cli"
	"tool/exec"
	"tool/os"
)

#Command: {
	#var: {
		vault?: {
			addr:       string
			namespace?: string
			env: {
				kv: {
					VAULT_ADDR: addr
					if vault.namespace != _|_ {
						VAULT_NAMESPACE: namespace
					}
				}
				rc: strings.Join([for k, v in kv {"export \(k)=\(v)"}], "\n")
			}
			method: string | *"oidc"
		}
		application: [N=string]: vault?: {
			kv: [string]: [...string]
		}
	}
	_local: withEnv: {
		env: os.Getenv & {HOME: _, PATH: _}
		for name, task in withEnv {
			if (task & exec.Run) != _|_ {
				(name): env: withEnv.env
			}
		}
	}
	if #var.vault != _|_ {
		// run `eval $(cue cmd vault-env)` to source
		"vault-env": cli.Print & {
			text: #var.vault.env.rc
		}
	}
	for name, app in #var.application {
		if app.vault != _|_ {
			// login vault with app args (shortcut)
			"vault-login": _
			// login vault with app args
			"vault-login-\(name)": _local.withEnv & {
				runP: exec.Run & {cmd: ["vault", "login", app.vault.login.args]}
			}
			// put secrets to vault kv (shortcut)
			"vault-put": _
			for kv, keys in app.vault.kv {
				// put secrets to vault kv
				VP="vault-put-\(name)": {
					// -1 as senitel of the loop
					"ask--1": cli.Ask & {
						prompt:   "Put secret to vault kv in \(#var.vault.addr) (^C to break, Enter to continue)"
						response: bool
					}
					for i, k in keys {
						"ask-\(i)": cli.Ask & {
							$after:   VP["ask-\(i-1)"]
							prompt:   "\(k):\t"
							response: string
						}
					}

					// NB with `runP`
					// command."vault-put".print.text: invalid string argument: non-concrete value string:
					run: exec.Run & {
						$after: VP["ask-\(len(keys)-1)"]
						cmd: ["vault", "put", app.vault.args, "--name", app.vault.kv]
					}
					print: cli.Print & {
						text: run.cmd
					}
				}
				// list secrets in vault (shortcut)
				"vault-list": _
				// list secrets in vault
				"vault-list-\(name)-\(kv)": {
					runP: exec.Run & {cmd: ["vault", "list", app.vault.args]}
				}
				// get secrets from vault (shortcut)
				"vault-get": _
				// get secrets from vault
				"vault-get-\(name)-\(kv)": {
					runP: exec.Run & {cmd: ["vault", "get", app.vault.args, "--name", app.vault.kv]}
				}
			}
		}
	}
}
