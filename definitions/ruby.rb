define :ruby, :export_path => true do
  version        = params[:version]
  home_dir       = params[:home]
  ruby_dir       = "#{home_dir}/#{version}"
  ruby_build_dir = "#{home_dir}/ruby-build"
  rubygems       = params[:rubygems]
  owner          = params[:owner]
  export_path    = params[:export_path]
  bin_dir        = "#{ruby_dir}/bin"
  ruby_bin       = "#{bin_dir}/ruby"
  bundler_bin    = "#{bin_dir}/bundle"
  gem_bin        = "#{bin_dir}/gem"

  if params[:exports]
    hash = Array(params[:exports]).inject(node.set){|memo, step| memo[step] }
    hash['ruby_computed'] = {
      'ruby_dir' => ruby_dir,
      'bin_dir'  => bin_dir,
      'gem_bin'  => gem_bin,
      'ruby_bin' => ruby_bin,
    }
  end

  git ruby_build_dir do
    repository "https://github.com/sstephenson/ruby-build.git"
    reference "master"
    action :sync
    user owner
    group owner
    not_if { File.exists?(ruby_dir) }
  end

  execute "install ruby #{ruby_dir}" do
    command "#{ruby_build_dir}/bin/ruby-build #{version} #{ruby_dir}"
    user owner
    group owner
    not_if { File.exists?(ruby_dir) }
  end

  if export_path
    profile_file = "#{home_dir}/.bashrc"

    file profile_file do
      owner owner
      group owner
      mode "0644"
      not_if { File.exists? profile_file }
    end

    ruby_block "append ruby path #{ruby_dir}" do
      comment = "# Generated by chef"
      path_definition = "export PATH=$HOME/#{version}/bin:$PATH"

      block do
        original_content = File.open(profile_file, 'r').read
        lines = original_content.split("\n")
        if lines.length > 2 && lines[0].start_with?(comment) && lines[1].start_with?("export PATH=")
          original_content = lines[2..-1].join("\n")
        end
        File.open(profile_file, 'w') do |f|
          f.puts comment
          f.puts path_definition
          f.puts original_content
        end
      end
      not_if { File.read(profile_file).include?(path_definition) }
    end
  end

  if rubygems
    execute "install rubygems - #{bin_dir}" do
      user owner
      cwd home_dir
      command "#{bin_dir}/gem update --system #{rubygems}"
      not_if %Q{test $(#{bin_dir}/gem --version) = "#{rubygems}"}
    end
  end

  env = {}
  env["PATH"]      = ENV["PATH"].split(":").push(bin_dir).join(":")
  env["JAVA_HOME"] = node[:java][:java_home] if node[:java] && node[:java][:java_home]

  execute "#{bin_dir}/gem install bundler --no-ri --no-rdoc" do
    environment(env)
    user owner
    not_if { File.exists?(bundler_bin) }
  end

end
