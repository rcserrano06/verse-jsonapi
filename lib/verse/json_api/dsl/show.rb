# frozen_string_literal: true

module Verse
  module JsonApi
    module Dsl
      class Show
        extend Helper

        attr_reader :parent, :exposition_class

        def initialize(exposition_class, parent, &block)
          @exposition_class = exposition_class
          @parent = parent

          instance_eval(&block) if block_given?
          install
        end

        instruction :path, ":resource_id"
        instruction :method, :get
        instruction :meta, {}, type: :hash

        instruction :body, type: :proc

        def install
          dsl = self

          default_body = proc do |service|
            key_name = dsl.path[/:(\w+)/, 1]&.to_sym
            service.show(params[key_name.to_sym], included: params.fetch(:included, []))
          end

          body = @body || default_body

          @exposition_class.class_eval do
            expose on_http(
              dsl.method,
              Helper.build_path(dsl.parent.path, dsl.path),
              renderer: Verse::JsonApi::Renderer,
              **dsl.parent.http_opts
            ) do
              desc "Show a specific `#{dsl.parent.resource_class.type}`"
              input dsl.show_input_schema
              output dsl.show_output_schema
              meta(dsl.meta) if dsl.meta
            end
            define_method(:show) {
              renderer.fields = params.fetch(:fields, {})
              service = send(dsl.parent.service) if respond_to?(dsl.parent.service)

              instance_exec(
                service,
                proc { instance_exec(service, &default_body) },
                &body
              )
            }
          end
        end

        def show_input_schema
          dsl = self

          Verse::Schema.define(parent.base_schema) do
            key_name = dsl.path[/:(\w+)/, 1]&.to_sym

            raise "incorrect path for show: `#{path}`" unless key_name

            resource_class = dsl.parent.resource_class
            pkey = resource_class.primary_key

            type = resource_class.fields[pkey].fetch(:type, Object)

            field(key_name, type)
            field?(:included, Array, of: String).rule("included unauthorized"){ |value| value.all?{ |v| dsl.parent.allowed_included.include?(v) } }

            field?(:fields, Hash, of: Array).transform do |fields|
              fields.transform_values do |arr|
                arr.map(&:to_sym)
              end
            end
          end
        end

        def show_output_schema
          Util.jsonapi_record(parent.resource_class)
        end
      end
    end
  end
end
