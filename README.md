# Boilerplate Application

**Description**: Document Intake & E-Sign Platform. Full Service.

# Workflows

Our different workflows. We strive to adhere to this variation of Git Flow.

## Engineering Workflow

* When you start working on a ticket, move the ticket to status *Fix*.
* Create a branch from `master` with the branch name `dev/XXXX-whatever-the-ticket-does`, where `XXXX` is the Redmine ticket number. This is important to allow automation to match your branch to the Redmine ticket.
* When your work is done, create a commit with the format: `[#XXXX] Whatever the ticket does`, where `XXXX` is the Redmine ticket number.
* When you push your branch, automation will pick it up and automatically add it to Redmine issue.
* After this you can deploy your change using the command line with `./deploy-cli.sh XXXX`, this will deploy it to Nomad for Design Review and move to the ticket automatically to the correct status.
* If there are changes requested, you will receive the ticke back in Fix status. Simply push to the branch and deploy again when done.
* **NEW**: You can also use our cluster for deploying by going to https://deploys.internal.boilerplate.co/ci
