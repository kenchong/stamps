require 'hashie'
require 'savon'
require File.expand_path('../response', __FILE__)

module Stamps

  # Defines HTTP request methods
  module Request

    # Perform an HTTP request
    def request(web_method, params, raw=false)
      client = Savon::Client.new do |wsdl, http|
        wsdl.endpoint = self.endpoint
        wsdl.namespace = self.namespace
      end

      client.http.open_timeout = self.open_timeout if self.open_timeout
      client.http.read_timeout = self.read_timeout if self.read_timeout

      response = client.request :tns, web_method do
        http.headers = { "SoapAction" => formatted_soap_action(web_method) }
        soap.namespace = 'tns'
        soap.element_form_default = :qualified
        soap.env_namespace = 'soap'
        soap.namespaces["xmlns:tns"] = self.namespace
        soap.body = params.to_hash
      end
      Stamps::Response.new(response).to_hash
    end

    # Get the Authenticator token. By using an Authenticator, the integration
    # can be sure that the conversation between the integration and the SWS
    # server is kept in sync and no messages have been lost.
    #
    def authenticator_token
      @authenticator ||= self.get_authenticator_token
    end

    # Make Authentication request for the user
    #
    def get_authenticator_token
      response = self.request('AuthenticateUser',
        Stamps::Mapping::AuthenticateUser.new(
          :credentials => {
            :integration_id => self.integration_id,
            :username       => self.username,
            :password       => self.password
        })
      )
      update_authenticator(response, :authenticate_user_response)
    end

    # Concatenates namespace and web method in a way the API can understand
    def formatted_soap_action(web_method)
      [self.namespace, web_method.to_s].compact.join('/')
    end

    def update_authenticator(response, web_method_response)
      if response.valid?
        @authenticator = response[web_method_response.to_sym][:authenticator]
      else
        @authenticator = nil
      end
    end
  end
end
