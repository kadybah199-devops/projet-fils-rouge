Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/jammy64"

  #########################################
  # Jenkins
  #########################################
  config.vm.define "jenkins" do |jenkins|
    jenkins.vm.hostname = "jenkins"

    jenkins.vm.network "private_network", ip: "192.168.56.10"

    jenkins.vm.provider "virtualbox" do |vb|
      vb.name = "jenkins"
      vb.memory = 4096
      vb.cpus = 2
    end

    jenkins.vm.provision "shell", path: "scripts/install_docker.sh"
  end

  #########################################
  # App (Flask + pgAdmin)
  #########################################
  config.vm.define "app" do |app|
    app.vm.hostname = "app"

    app.vm.network "private_network", ip: "192.168.56.11"

    app.vm.provider "virtualbox" do |vb|
      vb.name = "app"
      vb.memory = 2048
      vb.cpus = 2
    end

    app.vm.provision "shell", path: "scripts/install_docker.sh"
  end

  #########################################
  # Odoo
  #########################################
  config.vm.define "odoo" do |odoo|
    odoo.vm.hostname = "odoo"

    odoo.vm.network "private_network", ip: "192.168.56.12"

    odoo.vm.provider "virtualbox" do |vb|
      vb.name = "odoo"
      vb.memory = 2048
      vb.cpus = 2
    end

    odoo.vm.provision "shell", path: "scripts/install_docker.sh"
  end

end