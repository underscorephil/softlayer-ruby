#
# Copyright (c) 2014 SoftLayer Technologies, Inc. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

module SoftLayer
  # Server is the base class for VirtualServer and BareMetalServer.
  # It implements some functionality common to both those classes.
  #
  # Server is an abstract class and you should not create them
  # directly.
  #
  # While VirtualServer and BareMetalServer each have analogs
  # in the SoftLayer API, those analogs do not share a direct
  # ancestry.  As a result there is no SoftLayer API analog
  # to this class.
  class Server  < SoftLayer::ModelBase

    ##
    # :attr_reader:
    # The host name SoftLayer has stored for the server
    sl_attr :hostname

    ##
    # :attr_reader:
    # The domain name SoftLayer has stored for the server
    sl_attr :domain

    ##
    # :attr_reader:
    # A convenience attribute that combines the hostname and domain name
    sl_attr :fullyQualifiedDomainName

    ##
    # :attr_reader:
    # The data center where the server is located
    sl_attr :datacenter

    ##
    # :attr_reader:
    # The IP address of the primary public interface for the server
    sl_attr :primary_public_ip, "primaryIpAddress"

    ##
    # :attr_reader:
    # The IP address of the primary private interface for the server
    sl_attr :primary_private_ip, "primaryBackendIpAddress"

    ##
    # :attr_reader:
    # Notes about these server (for use by the customer)
    sl_attr :notes

    ##
    # Construct a server from the given client using the network data found in +network_hash+
    #
    # Most users should not have to call this method directly. Instead you should access the
    # servers property of an Account object, or use methods like BareMetalServer#find_servers
    # or VirtualServer#find_servers
    #
    def initialize(softlayer_client, network_hash)
      if self.class == Server
        raise RuntimeError, "The Server class is an abstract base class and should not be instantiated directly"
      else
        super
      end
    end

    ##
    # Make an API request to SoftLayer and return the latest properties hash
    # for this object.
    def softlayer_properties(object_mask = nil)
      my_service = self.service

      if(object_mask)
        my_service = my_service.object_mask(object_mask)
      else
        my_service = my_service.object_mask(self.class.default_object_mask.to_sl_object_mask)
      end

      my_service.getObject()
    end

    ##
    # Change the notes of the server
    # raises ArgumentError if you pass nil as the notes
    def notes=(new_notes)
      raise ArgumentError.new("The new notes cannot be nil") unless new_notes

      edit_template = {
        "notes" => new_notes
      }

      self.service.editObject(edit_template)
      self.refresh_details()
    end

    ##
    # Change the user metadata for the server.
    #
    def user_metadata=(new_metadata)
      raise ArgumentError.new("Cannot set user metadata to nil") unless new_metadata
      self.service.setUserMetadata([new_metadata])
      self.refresh_details()
    end

    ##
    # Change the hostname of this server
    # Raises an ArgumentError if the new hostname is nil or empty
    #
    def set_hostname!(new_hostname)
      raise ArgumentError.new("The new hostname cannot be nil") unless new_hostname
      raise ArgumentError.new("The new hostname cannot be empty") if new_hostname.empty?

      edit_template = {
        "hostname" => new_hostname
      }

      self.service.editObject(edit_template)
      self.refresh_details()
    end

    ##
    # Change the domain of this server
    #
    # Raises an ArgumentError if the new domain is nil or empty
    # no further validation is done on the domain name
    #
    def set_domain!(new_domain)
      raise ArgumentError.new("The new hostname cannot be nil") unless new_domain
      raise ArgumentError.new("The new hostname cannot be empty") if new_domain.empty?

      edit_template = {
        "domain" => new_domain
      }

      self.service.editObject(edit_template)
      self.refresh_details()
    end

    ##
    # Change the current port speed of the server
    #
    # +new_speed+ is expressed Mbps and should be 0, 10, 100, or 1000.
    # Ports have a maximum speed that will limit the actual speed set
    # on the port.
    #
    # Set +public+ to +false+ in order to change the speed of the
    # primary private network interface.
    #
    def change_port_speed(new_speed, public = true)
      if public
        self.service.setPublicNetworkInterfaceSpeed(new_speed)
      else
        self.service.setPrivateNetworkInterfaceSpeed(new_speed)
      end

      self.refresh_details()
      self
    end

    ##
    # Begins an OS reload on this server.
    #
    # The OS reload can wipe out the data on your server so this method uses a
    # confirmation mechanism built into the underlying SoftLayer API. If you
    # call this method once without a token, it will not actually start the
    # reload. Instead it will return a token to you. That token is good for
    # 10 minutes. If you call this method again and pass that token **then**
    # the OS reload will actually begin.
    #
    # If you wish to force the OS Reload and bypass the token safety mechanism
    # pass the token 'FORCE' as the first parameter. If you do so
    # the reload will proceed immediately.
    #
    def reload_os!(token = '', provisioning_script_uri = nil, ssh_keys = nil)
      configuration = {}

      configuration['customProvisionScriptUri'] = provisioning_script_uri if provisioning_script_uri
      configuration['sshKeyIds'] = ssh_keys if ssh_keys

      self.service.reloadOperatingSystem(token, configuration)
    end

    def to_s
      result = super
      if respond_to?(:hostname) then
        result.sub!('>', ", #{hostname}>")
      end
      result
    end

    protected

    # returns the default object mask for all servers
    # structured as a hash so that the classes BareMetalServer
    # and VirtualServer can use hash construction techniques to
    # specialize the mask for their use.
    def self.default_object_mask
      { "mask" => [
          'id',
          'globalIdentifier',
          'notes',
          'hostname',
          'domain',
          'fullyQualifiedDomainName',
          'datacenter',
          'primaryIpAddress',
          'primaryBackendIpAddress',
          { 'operatingSystem' => {
              'softwareLicense.softwareDescription' => ['manufacturer', 'name', 'version','referenceCode'],
              'passwords' => ['username','password']
            }
          },
          'privateNetworkOnlyFlag',
          'userData',
          'networkComponents.primarySubnet[id, netmask, broadcastAddress, networkIdentifier, gateway]',
          'billingItem[id,recurringFee]',
          'hourlyBillingFlag',
          'tagReferences[id,tag[name,id]]',
          'networkVlans[id,vlanNumber,networkSpace]',
          'postInstallScriptUri'
        ]
      }
    end

  end # class Server
end # module SoftLayer
