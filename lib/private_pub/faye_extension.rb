module PrivatePub
  # This class is an extension for the Faye::RackAdapter.
  # It is used inside of PrivatePub.faye_app.
  class FayeExtension

		def initialize(opts)
			@opts = opts
		end

    # Callback to handle incoming Faye messages. This authenticates both
    # subscribe and publish calls.
    def incoming(message, callback)
      if message["channel"] == "/meta/subscribe"
        if authenticate_subscribe(message)
					server = @opts[:adapter].instance_variable_get("@server")
					engine = server.engine.instance_variable_get("@engine")
					engine.client_map_put(message["ext"]["client_id"], message["clientId"])
				end
			elsif message["channel"] == "/meta/unsubscribe"
				server = @opts[:adapter].instance_variable_get("@server")
				engine = server.engine.instance_variable_get("@engine")
				clientId = engine.client_map_lookup(message["data"]["data"]["client_id"])
				if clientId and PrivatePub.config[:secret_token] == message["data"]["data"]["token"]
					engine.unsubscribe(clientId, message["data"]["data"]["channel"])
				end
      elsif message["channel"] !~ %r{^/meta/}
        authenticate_publish(message)
      end
      callback.call(message)
    end

  private

    # Ensure the subscription signature is correct and that it has not expired.
    def authenticate_subscribe(message)
      subscription = PrivatePub.subscription(:channel => message["subscription"], :timestamp => message["ext"]["private_pub_timestamp"])
      if message["ext"]["private_pub_signature"] != subscription[:signature]
        message["error"] = "Incorrect signature."
				false
      elsif PrivatePub.signature_expired? message["ext"]["private_pub_timestamp"].to_i
        message["error"] = "Signature has expired."
				false
			else
				true
			end
    end

    # Ensures the secret token is correct before publishing.
    def authenticate_publish(message)
      if PrivatePub.config[:secret_token].nil?
        raise Error, "No secret_token config set, ensure private_pub.yml is loaded properly."
      elsif message["ext"]["private_pub_token"] != PrivatePub.config[:secret_token]
        message["error"] = "Incorrect token."
      else
        message["ext"]["private_pub_token"] = nil
      end
    end
  end
end
