# frozen_string_literal: true

require_relative "./class_methods"

module Verse
  module Model
    module Repository
      class Base
        extend ClassMethods

        attr_reader :auth_context, :metadata

        def initialize(auth_context)
          @auth_context = auth_context
          @metadata = {}
        end

        def filtering
          # :nocov:
          raise NotImplementedError, "please implement filtering algorithm" # :nocov:
          # :nocov:
        end

        def transaction(&block)
          # :nocov:
          raise NotImplementedError, "please implement transaction"
          # :nocov:
        end

        def after_commit(&block)
          # :nocov:
          raise NotImplementedError, "please implement after_commit"
          # :nocov:
        end

        event
        def update(id, attributes, scope = scoped(:updated))
          attributes = encode(attributes)
          update_impl(id, attributes, scope)
        end

        protected def update_impl(id, attributes, scope)
          # :nocov:
          raise NotImplementedError, "please implement update"
          # :nocov:
        end

        event("created", creation: true)
        def create(attributes, scope = scoped(:create))
          attributes = encode(attributes)
          create_impl(attributes)
        end

        protected def create_impl(attributes)
          # :nocov:
          raise NotImplementedError, "please implement create"
          # :nocov:
        end

        event("deleted")
        def delete(id, scope = scoped(:delete))
          # :nocov:
          raise NotImplementedError, "please implement delete"
          # :nocov:
        end

        def find_by(
          filter,
          scope: scoped(:read),
          included: [],
          record: self.class.model_class
        )
          filter = encode_filters(filter)
          find_by_impl(
            filter,
            scope: scope,
            included: included,
            record: record
          )
        end

        def find_by_impl(
          filter,
          scope: scoped(:read),
          included: [],
          record: self.class.model_class
        )
          # :nocov:
          raise NotImplementedError, "please implement find_by"
          # :nocov:
        end

        query
        def index(
          filters = {},
          scope: scoped(:read),
          included: [],
          page: 1,
          items_per_page: 1_000,
          sort: nil,
          record: self.class.model_class,
          query_count: true
        )
          filters = encode_filters(filters)

          index_impl(
            filters,
            scope: scope,
            included: included,
            page: page,
            items_per_page: items_per_page,
            sort: sort,
            record: record,
            query_count: query_count
          )
        end

        protected def index_impl(
          filters,
          scope: scoped(:read),
          included: [],
          page: 1,
          items_per_page: 50,
          sort: nil,
          record: self.class.model_class,
          query_count: true
        )
          # :nocov:
          raise NotImplementedError, "please implement index"
          # :nocov:
        end

        ## === Selectors throwing exceptions ===
        def find_by!(filters, **opts)
          record = find_by(filters, **opts)

          raise Verse::Error::RecordNotFound, filters.inspect unless record

          record
        end

        def update!(id, attributes, scope = scoped(:update))
          output = update(id, attributes, scope)
          raise Verse::Error::RecordNotFound, id unless output
        end

        def delete!(id, scope = scoped(:delete))
          output = delete(id, scope)
          raise Verse::Error::RecordNotFound, id unless output
        end
        ## === ===

        def with_metadata(metadata)
          old_metadata = @metadata
          @metadata = @metadata.merge(metadata)
          yield
        ensure
          @metadata = old_metadata
        end

        # Redefine if the adapter allow multiple connection for read or write.
        def mode(_read_write)
          yield
        end

        def chunked_index(filters: {}, scope: scoped(:read), included: [], page: 1, items_per_page: 50, sort: nil)
          Verse::Util::Iterator.chunk_iterator page do |current_page|
            result = index(
              filters: filters,
              scope: scope,
              included: included,
              page: current_page,
              items_per_page: items_per_page,
              sort: sort,
              query_count: false
            )

            result.count == 0 ? nil : result
          end
        end

        # Disable automatic events on this specific call.
        # ```
        #  repo.no_event do
        #    repo.update(...) # Not event will be triggered to the event bus.
        #  end
        # ```
        #
        def no_event
          @disable_event = true
          yield(self)
        ensure
          @disable_event = false
        end

        protected

        def decode(hash)
          return hash unless self.class.encoders

          dup = hash.dup

          dup.each do |key, value|
            encoder = self.class.encoders[key.to_s]

            next unless encoder

            dup[key] = encoder.decode(value)
          end

          dup
        end

        def encode(hash)
          return hash unless self.class.encoders

          dup = hash.dup

          dup.each do |key, value|
            encoder = self.class.encoders[key.to_s]

            next unless encoder

            dup[key] = encoder.encode(value)
          end

          dup
        end

        def encode_filters(hash)
          return hash unless self.class.encoders

          dup = hash.dup

          dup.each do |key, value|
            field = key.to_s.split("__").first

            encoder = self.class.encoders[field]

            next unless encoder

            dup[key] = if field.is_a?(Array) && filtering.expect_array?(field)
                         value.map{ |x| encoder.encode(x) }
                       else
                         encoder.encode(value)
                       end
          end

          dup
        end

        def encode_array(array)
          return array unless self.class.encoders

          array.map{ |h| encode(h) }
        end

        def decode_array(array)
          return array unless self.class.encoders

          array.map{ |h| decode(h) }
        end

        def scoped(action)
          # :nocov:
          raise NotImplementedError, "please redefine scoped on child repositories and use @auth_context to filter."
          # :nocov:
        end

        def can_create?(auth_context, &block)
          auth_context.can!(:create, aggregate_name) do |scope|
            scope.all?(&block)
          end
        end

        def can_update?(auth_context, &block)
          auth_context.can!(:update, aggregate_name) do |scope|
            scope.all?(&block)
          end
        end

        # return a hash tree from the include list:
        # ["a.b.c", "c.d"] => { a: {b: {c: {}}}, c: {d: {}} }
        def tree_from_include_list(include, root = {})
          include.filter{ |x| x.is_a?(String) }.each_with_object(root) do |inc, root| # rubocop:disable Lint/ShadowingOuterLocalVariable
            first_part, remainer = inc.split "."
            root[first_part] = tree_from_include_list(
              [remainer].compact,
              root.fetch(first_part, {})
            )
          end
        end

        def prepare_included(included_list, collection, record: self.class.model_class)
          set = IncludeSet.new(included_list)
          tree = tree_from_include_list included_list

          tree.each do |key, _value|
            sub_included = \
              included_list \
              .filter{ |x| x =~ /^#{key}($|\.)/ } \
              .map{ |x| x.gsub(/^#{key}($|\.)/, "") }
              .reject(&:empty?)

            relation = record.relations.fetch(key.to_sym){ raise "Relation not found: #{key}" }

            # include_list,                                     # the list we store
            # ->(included) { included[primary_key.to_s] },      # The index where to store in the set
            # ->(record, set) { set[record[foreign_key.to_s]] } # the method to reconnect the set
            list, index_callback, record_callback = relation.call(
              collection, auth_context, sub_included
            )

            set.set_lookup_method([record, key], &record_callback)

            list.each do |element|
              set.add([record, key], index_callback.call(element), element)
            end
          end

          set
        end
      end
    end
  end
end
