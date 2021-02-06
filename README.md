<h1 align="center">Ansible Rails Provision and Deployment</h1>

You can find a more in-depth [blog post here](https://www.pedroalonso.net)

This is a sample Rails 6.1 app with an Ansible Rails playbook (inside .deploy folder) for easily provisioning an Ubuntu 20.04 server and deploying the app.

While this is meant to work out of the box, you can tweak the files in the `roles` directory in order to satisfy your project-specific requirements. 

---

### What does this do?
* Configure Ubuntu 20.04 server with some sensible defaults.
* Install required/useful packages. See notes below for more details.
* Auto upgrade all installed packages
* Create a new deployment user (called 'deploy') with passwordless login
* SSH hardening
    * Prevent password login
    * Change the default SSH port
    * Prevent root login
* Setup UFW (firewall)
* Setup Fail2ban
* Install Logrotate
* Setup Nginx with some sensible config (thanks to nginxconfig.io)
* Certbot (for Let's encrypt SSL certificates)
* Ruby (using Rbenv). 
    * Defaults to `2.7.2`. You can change it in the `app-vars.yml` file
    * [jemmaloc](https://github.com/jemalloc/jemalloc) is also installed and configured by default
    * [rbenv-vars](https://github.com/rbenv/rbenv-vars) is also installed by default
* Node.js 
    * Defaults to 15.x. You can change it in the `app-vars.yml` file.
* Yarn
* Redis (latest)
* Postgresql. 
    * Defaults to v13. You can specify the version that you need in the `app-vars.yml` file.
* Puma (with Systemd support for restarting automatically) **See Puma Config section below**
* Sidekiq (with Systemd support for restarting automatically)
* Ansistrano hooks for performing the following tasks - 
    * Installing all our gems
    * Precompiling assets
    * Migrating our database (using `run_once`)

---

## Getting started
Here are the steps that you need to follow in order to get up and running with Ansible Rails. 

### Step 1. Installation

You can just copy the .deploy folder in your Rails application folder, or clone this repo.

### Step 2. Storing sensitive data for Ansible
Create a new `vault` file to store sensitive information, using [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

```
ansible-vault create group_vars/all/vault.yml
```

Add the following information to this new vault file
```
vault_postgresql_db_password: "XXXXX_SUPER_SECURE_PASS_XXXXX"
vault_rails_master_key: "XXXXX_MASTER_KEY_FOR_RAILS_XXXXX"
```

**Note**: I prefer to keep these secrets in Environment variables as part of CI (I'll show how to do this using Github Actions)

### Step 3. Configuration
Configure the relevant variables in `app-vars.yml`.

```
app_name:           YOUR_APP_NAME   // Replace with name of your app
app_git_repo:       "YOUR_GIT_REPO" // e.g.: github.com/EmailThis/et
app_git_branch:     "main"        // branch that you want to deploy (e.g: 'production')

postgresql_db_user:     "{{ deploy_user }}_postgresql_user"
postgresql_db_password: "{{ vault_postgresql_db_password }}" # from vault (see next section)
postgresql_db_name:     "{{ app_name }}_production"
```

### Step 4. Deploy

If you have booted up a clean Ubuntu Server, you can install all the dependencies for your Rails application running:

```
ansible-playbook -i inventories/development.ini provision.yml
```

To deploy this app to your production server, create another file inside `inventories` directory called `production.ini` with the following contents. For this, you would need a VPS. You can use [DigitalOcean](https://www.digitalocean.com), AWS or any other of your preference.

```
[web]
192.168.50.2 # replace with IP address of your server.

[all:vars]
ansible_ssh_user=deployer
ansible_python_interpreter=/usr/bin/python3
```

## Additional Configuration
####  Installing additional packages
By default, the following packages are installed. You can add/remove packages to this list by changing the `required_package` variable in `app-vars.yml`

####  Uncomplicated Firewall Configuration (UFW)

You can enable UFW by adding the role to `provision.yml` like so - 
```
roles:
    ...
    ...
    - role: ufw
      tags: ufw
```

Then you can set up the UFW rules in `app-vars.yml` like so -
```
ufw_rules:
  - { rule: "allow", proto: "tcp", from: "any", port: "80" }
  - { rule: "allow", proto: "tcp", from: "any", port: "443" }
```

#### Configure Certbot (Let's Encrypt SSL certificates)

TO DO

#### PostgreSQL Database Backups
By default, daily backup is enabled in the `app-vars.yml` file. In order for this to work, the following variables need to be set. If you do not wish to store backups, remove (or uncomment) these lines from `app-vars.yml`.

```
aws_key: "{{ vault_aws_key }}" # store this in group_vars/all/vault.yml that we created earlier
aws_secret: "{{ vault_aws_secret }}"

postgresql_backup_dir: "{{ deploy_user_path }}/backups"
postgresql_backup_filename_format: >-
  {{ app_name }}-%Y%m%d-%H%M%S.pgdump
postgresql_db_backup_healthcheck: "NOTIFICATION_URL (eg: https://healthcheck.io/)" # optional
postgresql_s3_backup_bucket: "DB_BACKUP_BUCKET" # name of the S3 bucket to store backups
postgresql_s3_backup_hour: "3"
postgresql_s3_backup_minute: "*"
postgresql_s3_backup_delete_after: "7 days" # days after which old backups should be deleted
```

#### Puma config

Update your config/puma.rb with settings for production.

--- 

### Credits
* [dresden-weekly/ansible-rails](https://github.com/dresden-weekly/ansible-rails)
* [emailthis/ansible-rails](https://github.com/EmailThis/ansible-rails)
---
