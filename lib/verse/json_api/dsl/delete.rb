# frozen_string_literal: true

module Verse
  module JsonApi
    module Dsl
      class Delete
        extend Helper

        attr_reader :parent, :exposition_class

        def initialize(exposition_class, parent, &block)
          @exposition_class = exposition_class
          @parent = parent

          instance_eval(&block) if block_given?
          install
        end

        instruction :path, ":resource_id"
        instruction :method, :delete
        instruction :meta, {}, type: :hash

        instruction :body, type: :proc
        instruction :schema

        def install
          dsl = self

          default_body = proc do |service|
            # Get the last parameter from the path, which is the key name
            # we are looking for
            key_name = dsl.path.scan(/:(\w+)/).last&.first&.to_sym
            server.response.status = 204

            service.delete(params[key_name.to_sym])

            server.no_content
          end

          body = @body || default_body

          @exposition_class.class_eval do
            expose on_http(
              dsl.method,
              Helper.build_path(dsl.parent.path, dsl.path),
              renderer: Verse::JsonApi::Renderer,
              **dsl.parent.http_opts
            ) do
              desc "Delete the `#{dsl.parent.resource_class.type}`"
              input dsl.delete_input_schema
              meta(dsl.meta) if dsl.meta
            end
            define_method(:delete) {
              service = send(dsl.parent.service) if respond_to?(dsl.parent.service)

              instance_exec(
                service,
                proc { instance_exec(service, &default_body) },
                &body
              )
            }
          end
        end

        def delete_input_schema
          key_name = path[/:(\w+)/, 1]&.to_sym

          raise "incorrect path for delete: `#{path}`" unless key_name

          dsl = self
          Verse::Schema.define(parent.base_schema) do
            resource_class = dsl.parent.resource_class
            pkey = resource_class.primary_key
            type = resource_class.fields[pkey].fetch(:type, Object)

            field(key_name, type)
          end
        end
      end
    end
  end
end
