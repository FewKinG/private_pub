module PrivatePub

	class MemoryEngine < Faye::Engine::Memory

		def initialize(server, options)
			super(server, options)
			@client_map = {}
		end

		def client_map_put(remote_id, clientId)
			@client_map[remote_id] = clientId
		end

		def client_map_lookup(remote_id)
			@client_map[remote_id]
		end

	end

end
