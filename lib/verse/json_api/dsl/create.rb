# frozen_string_literal: true

module Verse
  module JsonApi
    module Dsl
      class Create
        extend Helper

        attr_reader :parent, :exposition_class

        def initialize(exposition_class, parent, &block)
          @exposition_class = exposition_class
          @parent = parent

          instance_eval(&block) if block_given?
          install
        end

        instruction :path, ""
        instruction :method, :post
        instruction :meta, {}, type: :hash

        instruction :ignored_fields, [], type: :array

        instruction :authorized_relationships, {}, type: :hash

        instruction :body, type: :proc

        instruction :schema

        instruction :allow_id, false

        def install
          dsl = self

          default_body = proc do |service|
            server.response.status = 201
            service.create(params)
          end

          body = dsl.body || default_body

          @exposition_class.class_eval do
            expose on_http(dsl.method,
              Helper.build_path(dsl.parent.path, dsl.path),
              renderer: Verse::JsonApi::Renderer,
              **dsl.parent.http_opts
            ) do
              desc "Create a new `#{dsl.parent.resource_class.type}`"
              input dsl.create_input_schema
              output dsl.create_output_schema
              meta(dsl.meta) if dsl.meta
            end
            define_method(:create) do
              service = send(dsl.parent.service) if respond_to?(dsl.parent.service)

              instance_exec(
                service,
                proc { instance_exec(service, &default_body) },
                &body
              )
            end
          end
        end

        def create_input_schema
          dsl = self

          schema = @schema || Verse::Schema.define do
            dsl.parent.resource_class.fields.each do |field, config|
              field_name = [field.to_s, field.to_sym]

              next unless (field_name & dsl.ignored_fields).empty?
              next unless config[:visible]

              # Skip primary key field - it should be at root level when allow_id is true,
              # and not allowed at all when allow_id is false
              if config[:primary]
                next
              end

              type = config.fetch(:type, Object)

              field?(field, type).meta(**config.slice(:desc, :description, :example))
            end
          end

          relations = Verse::Schema.define do
            dsl.authorized_relationships
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
            field(:data, Hash) do
              field(:type, String).in?(dsl.parent.resource_class.type)
              field(:attributes, schema)

              # Allow id field at root level when allow_id is enabled
              if dsl.allow_id
                resource = dsl.parent.resource_class
                # Find the primary key field to determine its type
                primary_field = resource.primary_key

                field_type = resource.fields[primary_field][:type] || String
                field?(:id, field_type)
              end

              if relations.fields.any?
                field?(:relationships, relations)
              end
            end

            transform{ |hash| Deserializer.deserialize(hash) }
          end
        end

        def create_output_schema
          Util.jsonapi_record(parent.resource_class)
        end
      end
    end
  end
end
