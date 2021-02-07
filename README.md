<h1 align="center">Automate Rails Provision and Deployment using Ansible</h1>

You can find a more in-depth [**Blog Post Here**](https://www.pedroalonso.net)

This is a sample Rails 6.1 app with 2 Ansible Playbooks, inside `.ansible-deploy` folder. Provision playbook is used to easily provision an **Ubuntu 20.04 Server**, there's another playbook for deployment and rollback your Rails app using Ansistrano.

While this is meant to work out of the box, you can tweak the files in the `roles` directory in order to satisfy your project-specific requirements. 

---

### What does this do?
* Configure Ubuntu 20.04 Server with some sensible defaults.
* Install required/useful packages. You can [**update this list here**](https://github.com/pedropaf/rails-ansible-provision-deployment/blob/bb402ad2777dc6cf9d4e7225fb85cd0eafb2a3a1/.ansible-deploy/app-vars.yml#L53-L75).
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
* Certbot, for Let's encrypt SSL certificates.
* Ruby (using Rbenv).
    * Defaults to `2.7.2`. You can change it in the [`app-vars.yml`](https://github.com/pedropaf/rails-ansible-provision-deployment/blob/bb402ad2777dc6cf9d4e7225fb85cd0eafb2a3a1/.ansible-deploy/app-vars.yml#L78) file
    * [jemmaloc](https://github.com/jemalloc/jemalloc) is also installed and configured by default
    * [rbenv-vars](https://github.com/rbenv/rbenv-vars) is also installed by default
* Node.js 
    * Defaults to 15.x. You can change it in the [`app-vars.yml`](https://github.com/pedropaf/rails-ansible-provision-deployment/blob/bb402ad2777dc6cf9d4e7225fb85cd0eafb2a3a1/.ansible-deploy/app-vars.yml#L88) file.
* Yarn
* Redis (latest)
* Postgresql. 
    * Defaults to v13. You can specify the version that you need in the `app-vars.yml` file.
* Puma (with Systemd support for restarting automatically) **See Puma Config section below**.
* Sidekiq (with Systemd support for restarting automatically)
* Ansistrano hooks for performing the following tasks - 
    * Installing all our gems
    * Precompiling assets
    * Migrating our database (using `run_once`)

---

## Getting started
Here are the steps that you need to follow in order to get up and running with Ansible Rails. 

### Step 1. Installation

You can just copy the `.ansible-deploy` folder in your Rails application folder, or clone this repo.

### Step 2. Storing sensitive data for Ansible
As mentioned earlier, we have one Ansible Playbook to setup the serve, so the secret variables that are needed to setup the server, are stored in an Ansible Vault. The secrets related to the Rails app, should be stored using [Custom Credentials](https://edgeguides.rubyonrails.org/security.html#custom-credentials).

To create a new `Ansible Vault`(https://docs.ansible.com/ansible/latest/user_guide/vault.html) file to store sensitive information:

```bash
$ ansible-vault create .ansible-deploy/group_vars/all/vault.yml
```

Add the following information to this new vault file
```yaml
vault_postgresql_db_password: "XXXXX_SUPER_SECURE_PASS_XXXXX"
vault_rails_master_key: "XXXXX_MASTER_KEY_FOR_RAILS_XXXXX"
```

### Step 3. Configuration
Configure the relevant variables in `app-vars.yml`.

```yaml
app_name: YOUR_APP_NAME # Replace with name of your app
app_git_repo: "YOUR_GIT_REPO"
app_git_branch: "main" # branch that you want to deploy (e.g: 'production')

postgresql_db_user:     "{{ deploy_user }}_postgresql_user"
postgresql_db_password: "{{ vault_postgresql_db_password }}" # from vault (see previous section)
postgresql_db_name:     "{{ app_name }}_production"
```

### Step 4. Deploy

If you have booted up a clean Ubuntu Server, you can install all the dependencies for your Rails application running:

```bash
$ cd .ansible-deploy
$ ansible-playbook -i inventories/development.ini provision.yml
```

In Ansible, an inventory is called the list of server(s) where you want to run your playbook. If you want to use a different staging / production servers, you can have 2 inventory files one for each stage, called `staging.ini` / `production.ini`.
To deploy this app to your production server, you can use [DigitalOcean](https://www.digitalocean.com), AWS or any other hosting provider of your preference.

```yaml
[web]
192.168.0.1 # replace with IP address of your server.

[all:vars]
ansible_ssh_user=deployer
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file="~/.ssh/id_rsa"
```

## Additional Configuration
###  Installing additional packages
You can add/remove packages to this list by changing the `required_package` variable in `app-vars.yml`.
###  Uncomplicated Firewall Configuration (UFW)

Uncomplicated Firewall is enabled and accepting connections from any IP on ports 22 (ssh), 80 (http), and 443 (https). Feel free to update it in `app-vars.yml`.
### Configure Certbot (Let's Encrypt SSL certificates)

Certboot is configured to request, install and set up a CRON job to update your certificate when it expires. Setup your domain DNS as well as the details for your domain / email to request the certificate in [`app-vars.yml`](https://github.com/pedropaf/rails-ansible-provision-deployment/blob/bb402ad2777dc6cf9d4e7225fb85cd0eafb2a3a1/.ansible-deploy/app-vars.yml#L103).
### PostgreSQL Database Backups
By default, daily backup is enabled in the `app-vars.yml` file. In order for this to work, the following variables need to be set. If you do not wish to store backups, remove (or uncomment) these lines from `app-vars.yml`.

```yaml
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

Update your [**config/puma.rb**](https://github.com/pedropaf/rails-ansible-provision-deployment/blob/main/config/puma.rb) with settings for production.

```ruby
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

port ENV.fetch("PORT") { 3000 }

rails_env = ENV.fetch("RAILS_ENV") { "development" }
environment rails_env

if %w[production staging].member?(rails_env)
    app_dir = ENV.fetch("APP_DIR") { "YOUR_APP/current" }
    directory app_dir

    shared_dir = ENV.fetch("SHARED_DIR") { "YOUR_APP/shared" }

    # Logging
    stdout_redirect "#{shared_dir}/log/puma.stdout.log", "#{shared_dir}/log/puma.stderr.log", true
    
    pidfile "#{shared_dir}/tmp/pids/puma.pid"
    state_path "#{shared_dir}/tmp/pids/puma.state"
    
    # Set up socket location
    bind "unix://#{shared_dir}/sockets/puma.sock"
    
    workers ENV.fetch("WEB_CONCURRENCY") { 2 }
    preload_app!

elsif rails_env == "development"
    # Specifies the `worker_timeout` threshold that Puma will use to wait before
    # terminating a worker in development environments.
    worker_timeout 3600
    plugin :tmp_restart
end
```

--- 

### Credits

These 2 repos were a useful inspiration and starting point:

* [dresden-weekly/ansible-rails](https://github.com/dresden-weekly/ansible-rails)
* [emailthis/ansible-rails](https://github.com/EmailThis/ansible-rails)
---
