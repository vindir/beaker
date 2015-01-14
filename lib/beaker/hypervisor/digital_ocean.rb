module Beaker
  #Beaker support for digitalocean
  class DigitalOcean < Beaker::Hypervisor

    SLEEPWAIT = 5

    #Create a new instance of the digitalocean hypervisor object
    #@param [<Host>] digitalocean_hosts The array of digitalocean hosts to provision
    #@param [Hash{Symbol=>String}] options The options hash containing configuration values
    #@option options [String] :digitalocean_api_key The key to access the digitalocean instance with (required)
    #@option options [String] :digitalocean_username The username to access the digitalocean instance with (required)
    #@option options [String] :digitalocean_auth_url The URL to access the digitalocean instance with (required)
    #@option options [String] :digitalocean_tenant The tenant to access the digitalocean instance with (required)
    #@option options [String] :digitalocean_network The network that each digitalocean instance should be contacted through (required)
    #@option options [String] :digitalocean_keyname The name of an existing key pair that should be auto-loaded onto each
    #                                            digitalocean instance (optional)
    #@option options [String] :jenkins_build_url Added as metadata to each digitalocean instance
    #@option options [String] :department Added as metadata to each digitalocean instance
    #@option options [String] :project Added as metadata to each digitalocean instance
    #@option options [Integer] :timeout The amount of time to attempt execution before quiting and exiting with failure
    def initialize(digitalocean_hosts, options)
      require 'fog'
      @options = options
      @logger = options[:logger]
      @hosts = digitalocean_hosts
      @vms = []

      @compute_client ||= Fog::Compute.new(:provider => 'DigitalOcean',
                                           :digitalocean_api_key => 'FOO',
                                           :digitalocean_client_id => 'BAR')

      if not @compute_client
        raise "Unable to create DigitalOcean Compute instance"
      end
    end

    # Flavours are sizes
    def flavor f
      @logger.debug "Digitalocean: Looking up flavor '#{f}'"
      @compute_client.flavors.find { |x| x.name == f } || raise("Couldn't find flavor: #{f}")
    end

    #Provided an image name return the digitalocean id for that image
    #@param [String] i The image name
    #@return [String] digitalocean id for provided image name
    def image (dist, name)
      @logger.debug "Digitalocean: Looking up image - Dist: '#{dist}' Name: #{name}"
      @compute_client.images.find { |x| (x.name == name) && (x.distribution == dist)} #|| raise("Couldn't find image: #{dist} #{name}")
    end

    def region r
      @logger.debug "Digitalocean: Looking up region '#{r}'"
      @compute_client.regions.find { |x| x.name == r } || raise("Couldn't find region: #{r}")
    end

    #Create new instances in digitalocean
    def provision
      @logger.notify "Provisioning digitalocean"

      @hosts.each do |host|
        host[:vmhostname] = generate_host_name
        @logger.debug "Provisioning #{host.name} (#{host[:vmhostname]})"

        vm = @compute_client.servers.bootstrap({
          :name => host[:vmhostname],
          :image_id => image(host[:image_distribution], host[:image_name]).id,
          :region_id => region(host[:region]).id,
          :flavor_id => flavor(host[:flavor]).id,
          :public_key_path => File.expand_path('~/.ssh/id_rsa.pub'),
          :private_key_path => File.expand_path('~/.ssh/id_rsa'),
        })
        @logger.debug "Waiting for #{host.name} (#{host[:vmhostname]}) to respond"
        vm.wait_for { ready? }

        host[:ip] = vm.public_ip_address

        @vms << vm

      end
    end

    #Destroy any digitalocean instances
    def cleanup
      @logger.notify "Cleaning up digitalocean"
      @vms.each do |vm|
        @logger.debug "Destroying digitalocean host #{vm.name}"
        vm.destroy
      end
    end

  end
end
