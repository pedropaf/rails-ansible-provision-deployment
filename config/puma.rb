# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
#
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