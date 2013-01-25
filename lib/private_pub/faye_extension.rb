module PrivatePub
  # This class is an extension for the Faye::RackAdapter.
  # It is used inside of PrivatePub.faye_app.
  class FayeExtension

		attr_accessor :client_name_map

		def initialize(opts)
			@opts = opts
			self.client_name_map = {}
		end

		def client_map_add(name, id)
			self.client_name_map[name] ||= {}
			client_map_clean(name)
			self.client_name_map[name][id] = Time.now
		end

		def client_map_clean(name)
			if map = self.client_name_map[name]
				map.keys.each do |k|
					if map[k] and map[k] < Time.now - PrivatePub.config[:signature_expiration]
						map[k] = nil
					end
				end
			end
		end

		def client_map_get(name)
			client_map_clean name
			if map = self.client_name_map[name]
				map.keys
			else
				[]
			end
		end

    # Callback to handle incoming Faye messages. This authenticates both
    # subscribe and publish calls.
    def incoming(message, callback)
      if message["channel"] == "/meta/subscribe"
        if authenticate_subscribe(message)
					if name = message["ext"]["clientName"]
						client_map_add name, message["clientId"]
					end
				end
			elsif message["channel"] == "/meta/unsubscribe"
				if message["ext"]["private_pub_token"]
					# Message is from server
					if authenticate_publish(message)
						message["error"] = "Incorrect token."
					else
						name = message["ext"]["clientName"]
						client_map_get(name).each do |id|
							m = Faye.copy_object(message)
							m["clientId"] = id
							callback.call(m)
						end
						return
					end
				end
      elsif message["channel"] !~ %r{^/meta/}
        authenticate_publish(message)
      end
      callback.call(message)
    end

  private

    # Ensure the subscription signature is correct and that it has not expired.
    def authenticate_subscribe(message)
      subscription = PrivatePub.subscription(:channel => message["subscription"], :timestamp => message["ext"]["private_pub_timestamp"], :client_name => message["ext"]["clientName"])
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
