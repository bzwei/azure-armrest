module Azure
  module Armrest
    # Abstract base class for the other manager classes.
    class ArmrestManager

      # The subscription ID (billing unit) for your Azure services
      attr_accessor :subscription_id

      # The resource group within the subscription.
      attr_accessor :resource_group

      # The API version of the REST interface. The default is 2015-1-1.
      attr_accessor :api_version

      # Base url used for REST calls.
      attr_accessor :base_url

      # The bearer token set in the constructor.
      attr_accessor :token

      # The content-type use for requests.
      attr_reader :content_type

      # The oauth2 strategy used for gathering the authentication token.
      # The default is 'client_credentials'.
      attr_reader :grant_type

      VALID_OPTIONS = %[
        client_id
        client_key
        tenant_id
        subscription_id
        resource_group
        api_version
        grant_type
        content_type
        token
      ]

      @@client_id = nil
      @@client_key = nil
      @@tenant_id = nil
      @@subscription_id = nil
      @@resource_group = nil
      @@api_version = '2015-01-01'
      @@grant_type = 'client_credentials'
      @@content_type = 'application/json'
      @@token = nil

      # Set configuration options globally. If set globally you do not need to
      # pass configuration options to individual manager classes.
      #
      # Possible options are:
      #
      #   - client_id
      #   - client_key
      #   - tenant_id
      #   - subscription_id
      #   - resource_group
      #   - api_version
      #   - grant_type
      #   - content_type
      #   - token
      #
      # Of these, you should include a client_id, client_key and tenant_id.
      # The resource_group can be specified here, but many methods allow you
      # to specify a resource group if you prefer flexibility.
      #
      # If no subscription_id is provided then this method will attempt to find
      # a list of associated subscriptions and use the first one it finds as
      # the default. If no associated subscriptions are found, an ArgumentError
      # is raised.
      #
      # The other options (grant_type, content_type, token, and api_version)
      # should generally NOT be set by you except in specific circumstances.
      # Setting them explicitly will likely cause breakage.
      #
      # You may need to associate your application with a subscription using
      # the portal or the New-AzureRoleAssignment powershell command.
      #
      def self.configure(options)
        options.each do |k,v|
          raise ArgumentError, "Invalid key: '#{k}'" unless VALID_OPTIONS.include?(k.to_s)
          eval("@@#{k} = v")
        end

        token_url = Azure::Armrest::AUTHORITY + @@tenant_id + "/oauth2/token"

        response = RestClient.post(
          token_url,
          :grant_type    => @@grant_type,
          :client_id     => @@client_id,
          :client_secret => @@client_key,
          :resource      => Azure::Armrest::RESOURCE
        )

        @@token = 'Bearer ' + JSON.parse(response)['access_token']

        # Automatically set a subscription ID if one is not specified.
        unless @@subscription_id
          url = File.join(Azure::Armrest::RESOURCE, "subscriptions?api-version=#{@@api_version}")

          response = RestClient.get(
            url,
            :content_type  => @@content_type,
            :authorization => @@token,
          )

          hash = JSON.parse(response.body)["value"].first

          if hash.empty?
            raise ArgumentError, "No associated subscription found"
          else
            @@subscription_id = hash.fetch("subscriptionId")
          end
        end
      end

      # Do not instantiate directly. This is an abstract base class from which
      # all other manager classes should subclass, and call super within their
      # own constructors.
      #
      # The possible options to the constructor are:
      #
      # * subscription_id - Your Azure subscription ID. If no subscription
      #     is specifified, then information for all subscriptions will be
      #     collected.
      #
      # * resource_group - The resource group within the subscription. If no
      #     resource group is specified, then information for all resource
      #     groups will be gathered.
      #
      # * client_id - Your Azure client ID. Mandatory.
      #
      # * client_key - The key (secret) for your client ID. Mandatory.
      #
      # * tenant_id - Your Azure tenant ID. Mandatory.
      #
      # * api_version - The REST API version to use for internal REST calls.
      #     The default is '2015-01-01'. You will typically not set this
      #     as it could cause breakage.
      #
      def initialize(options = {})
        # Mandatory params
        @client_id  = @@client_id || options.fetch(:client_id)
        @client_key = @@client_key || options.fetch(:client_key)
        @tenant_id  = @@tenant_id || options.fetch(:tenant_id)

        # Optional params
        @subscription_id = @@subscription_id || options[:subscription_id]
        @resource_group  = @@resource_group || options[:resource_group]
        @api_version     = @@api_version || options[:api_version] || '2015-01-01'
        @grant_type      = @@grant_type || options[:grant_type] || 'client_credentials'

        # The content-type used for all internal http requests
        @content_type = @@content_type || 'application/json'

        # Call the get_token method to set this.
        @token = @@token || options[:token]

        # Base URL used for REST calls. Modify within method calls as needed.
        @base_url = Azure::Armrest::RESOURCE
      end

      # Gets an authentication token, which is then used for all other methods.
      # This will also set the subscription_id to the first subscription found
      # if you did not set it in the constructor.
      #
      # If you did not call the the ArmrestManager.configure method then you
      # must call this before calling any other methods.
      #
      def get_token
        return self if @@token || @token

        token_url = Azure::Armrest::AUTHORITY + @tenant_id + "/oauth2/token"

        resp = RestClient.post(
          token_url,
          :grant_type    => @grant_type,
          :client_id     => @client_id,
          :client_secret => @client_key,
          :resource      => Azure::Armrest::RESOURCE
        )

        @token = 'Bearer ' + JSON.parse(resp)['access_token']
        @@token = @token

        unless @subscription_id
          @subscription_id = subscriptions.first['subscriptionId']
        end

        self
      end

      # Returns a list of the available resource providers.
      #
      def providers
        url = url_with_api_version(@base_url, 'providers')
        resp = rest_get(url)
        JSON.parse(resp.body)["value"]
      end

      # Returns a list of subscriptions for the tenant.
      #
      def subscriptions
        url = url_with_api_version(@base_url, 'subscriptions')
        resp = rest_get(url)
        JSON.parse(resp.body)["value"]
      end

      # Return information for the specified subscription ID, or the
      # subscription ID that was provided in the constructor if none is
      # specified.
      #
      def subscription_info(subscription_id = @subscription_id)
        url = url_with_api_version(@base_url, 'subscriptions', subscription_id)
        resp = rest_get(url)
        JSON.parse(resp.body)
      end

      # Returns a list of resource groups for the given subscription.
      #
      def resource_groups(subscription_id = @subscription_id)
        url = url_with_api_version(@base_url, 'subscriptions', subscription_id, 'resourcegroups')
        resp = rest_get(url)
        JSON.parse(resp.body)["value"]
      end

      # Returns information the specified resource group, or the
      # resource group specified in the constructor if none is provided.
      #
      def resource_group_info(resource_group = @resource_group)
        url = url_with_api_version(@base_url, 'subscriptions', subscription_id, 'resourcegroups', resource_group)
        resp = rest_get(url)
        JSON.parse(resp.body)
      end

      private

      # REST verb methods

      def rest_get(url)
        RestClient.get(
          url,
          :content_type  => @content_type,
          :authorization => @token,
        )
      end

      def rest_put(url)
        RestClient.put(
          url,
          :content_type  => @content_type,
          :authorization => @token,
        )
      end

      def rest_post(url)
        RestClient.post(
          url,
          :content_type  => @content_type,
          :authorization => @token,
        )
      end

      def rest_delete(url)
        RestClient.delete(
          url,
          :content_type  => @content_type,
          :authorization => @token,
        )
      end

      # Take an array of URI elements and join the together with the API version.
      def url_with_api_version(*paths)
        path = File.join(*paths) << "?api-version=#{api_version}"
      end

    end # ArmrestManager
  end # Armrest
end # Azure
