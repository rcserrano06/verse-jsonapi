# frozen_string_literal: true

module Verse
  module JsonApi
    module Dsl
      class Update
        extend Helper

        attr_reader :parent, :exposition_class

        def initialize(exposition_class, parent, &block)
          @exposition_class = exposition_class
          @parent = parent

          instance_eval(&block) if block_given?
          install
        end

        instruction :path, ":resource_id"
        instruction :method, :patch
        instruction :meta, {}, type: :hash

        instruction :ignored_fields, [], type: :array

        instruction :authorized_relationships, {}, type: :hash

        instruction :body, type: :proc
        instruction :schema

        def install
          dsl = self

          default_body = proc do |service|
            dsl.path[/:(\w+)/, 1]&.to_sym
            service.update(params)
          end

          body = @body || default_body

          @exposition_class.class_eval do
            expose on_http(
              dsl.method,
              Helper.build_path(dsl.parent.path, dsl.path),
              renderer: Verse::JsonApi::Renderer,
              **dsl.parent.http_opts
            ) do
              desc "Update a `#{dsl.parent.resource_class.type}`"
              input dsl.update_input_schema
              output dsl.update_output_schema
              meta(dsl.meta) if dsl.meta
            end
            define_method(:update) do
              service = send(dsl.parent.service) if respond_to?(dsl.parent.service)

              instance_exec(
                service,
                proc { instance_exec(service, &default_body) },
                &body
              )
            end
          end
        end

        def update_input_schema
          dsl = self

          schema = @schema || Verse::Schema.define do
            dsl.parent.resource_class.fields.each do |field, config|
              field_name = [field.to_s, field.to_sym]

              next unless (field_name & dsl.ignored_fields).empty?
              next unless config[:visible]

              type = config.fetch(:type, Object)

              unless config[:readonly]
                field?(field, type).meta(**config.slice(:desc, :description, :example))
              end
            end
          end

          relations = Verse::Schema.define do
            dsl.parent.resource_class.relations.each do |f, config|
              relationship_options = dsl.authorized_relationships[f]

              next unless relationship_options

              record = Verse::Schema.define do
                field(:data, Hash) do
                  field(:type, String).filled

                  if relationship_options.include?(:link)
                    field?(:id, String)
                  end

                  if relationship_options.include?(:create)
                    field?(:attributes, Hash)
                  end

                  rule([:id, :attributes], "must have either id or attributes") do |hash|
                    hash[:id].nil? ^ hash[:attributes].nil?
                  end
                end
              end

              if config.opts[:array]
                field(f, Array, of: record)
              else
                field(f, record)
              end
            end
          end

          Verse::Schema.define(parent.base_schema) do
            key_name = dsl.path[/:(\w+)/, 1]&.to_sym

            raise "incorrect path for update: `#{path}`" unless key_name

            resource_class = dsl.parent.resource_class
            pkey = resource_class.primary_key
            type = resource_class.fields[pkey].fetch(:type, Object)
            field(key_name, type)

            field(:data, Hash) do
              field(:type, String).in?(dsl.parent.resource_class.type)
              field(:attributes, schema)

              if relations.fields.any?
                field?(:relationships, relations)
              end
            end

            transform do |hash|
              hash[:data][:id] = hash[key_name]
              Deserializer.deserialize(hash)
            end
          end
        end

        def update_output_schema
          Util.jsonapi_record(parent.resource_class)
        end
      end
    end
  end
end
