require "pathname"

action :create do
  export_ruby_properties if new_resource.exports
  fetch_ruby_build
  install_ruby
  export_ruby_path if new_resource.export_path
  install_rubygems if new_resource.rubygems
  install_bundler
end

def export_ruby_properties
  hash = new_resource.exports.inject(node.set) { |memo, step| memo[step] }
  hash["ruby_computed"] = {
    "ruby_dir" => ruby_dir,
    "bin_dir"  => bin_dir,
    "gem_bin"  => gem_bin,
    "ruby_bin" => ruby_bin,
  }
end

def fetch_ruby_build
  r = git ruby_build_dir.to_s do
    repository "https://github.com/sstephenson/ruby-build.git"
    reference  "master"
    user  new_resource.owner
    group new_resource.owner
    action :sync

    not_if { ::File.exists?(ruby_dir) }
  end
end

def install_ruby
  r = execute "install ruby #{ruby_dir}" do
    command "#{ruby_build_dir}/bin/ruby-build #{ruby_version} #{ruby_dir}"
    user  new_resource.owner
    group new_resource.owner

    not_if { ::File.exists?(ruby_dir) }
  end
end

def export_ruby_path
  ruby_block "append ruby path #{ruby_dir}" do
    comment = "# Generated by chef"
    path_definition = "export PATH=$HOME/#{ruby_version}/bin:$PATH"

    block do
      original_content = bashrc_path.read
      lines            = original_content.split("\n")

      if lines[0].start_with?(comment) && lines[1].start_with?("export PATH=")
        original_content = lines[2..-1].join("\n")
      end

      bashrc_path.open('w') do |f|
        [comment, path_definition, original_content].each do |part|
          f.puts(part)
        end
      end
    end
    not_if { bashrc_path.read.include?(path_definition) }
  end
end

def install_rubygems
  r = execute "install rubygems - #{bin_dir}" do
    user new_resource.owner
    cwd  home_dir.to_s
    command "#{bin_dir}/gem update --system #{rubygems_version}"

    not_if %Q{test $(#{bin_dir}/gem --version) = "#{rubygems_version}"}
  end
end

def install_bundler
  env = {}
  env["PATH"]      = ENV["PATH"].split(":").push(bin_dir).join(":")
  env["JAVA_HOME"] = node[:java][:java_home] if node[:java] && node[:java][:java_home]

  r = execute "#{bin_dir}/gem install bundler --no-ri --no-rdoc" do
    environment(env)
    user new_resource.owner

    not_if { ::File.exists?(bundler_bin) }
  end
end

def home_dir
  Pathname.new(new_resource.home)
end

def bin_dir
  home_dir.join("bin")
end

def ruby_dir
  home_dir.join(ruby_version)
end

def ruby_build_dir
  home_dir.join("ruby-build")
end

def ruby_bin
  bin_dir.join("ruby")
end

def bundler_bin
  bin_dir.join("bundler")
end

def gem_bin
  bin_dir.join("gem")
end

def ruby_version
  new_resource.version
end

def rubygems_version
  new_resource.rubygems
end

def bashrc_path
  home_dir.join(".bashrc")
end
