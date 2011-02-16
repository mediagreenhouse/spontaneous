# encoding: UTF-8

module Spontaneous::Plugins
  module Entries

    def self.configure(base)
      base.__send__(:alias_method,  :<<, :push)
    end

    module InstanceMethods
      CONTENT_PATH_SEP = ".".freeze

      # because it's possible to build content out of order
      # some relations don't necessarily get created straight away
      def before_save
        if container
          self.page = container.page if page.nil?
          if page?
            self.depth = parent ? ((parent.depth || 0) + 1) : 0
          else
            self.depth = (container.content_depth || 0) + 1
          end
        end
        super
      end

      def destroy(remove_container_entry=true, container=nil)
        container ||= self.container
        if container && remove_container_entry
          container.destroy_entry!(self.entry)
        end
        super()
      end

      def before_destroy
        recursive_destroy
        super
      end

      def recursive_destroy
        all_entries.destroy
      end

      def destroy_entry!(entry)
        entries.remove(entry)
        # save the container because it won't be obvious to the caller
        # that content other than the destroyed object will have been
        # modified
        self.save
      end

      def content_depth
        depth
      end

      def entry_modified!(modified_entry)
        self.entry_store = all_entries.serialize
      end

      def entries
        if Spontaneous::Content.visible_only?
          visible_entries
        else
          all_entries
        end
      end

      def all_entries
        @all_entries ||= Spontaneous::EntrySet.new(self, entry_store)
      end

      def visible_entries
        @visible_entries ||= all_entries.visible!
      end

      protected(:all_entries, :visible_entries)

      def reload
        @all_entries = @visible_entries = nil
        super
      end


      def first
        entries.first
      end

      def last
        entries.last
      end

      def push(page_or_piece)
        insert(-1, page_or_piece)
      end

      def insert(index, page_or_piece, box = nil)
        save if new?
        if page_or_piece.page?
          insert_page(index, page_or_piece, box)
        else
          insert_piece(index, page_or_piece, box)
        end
      end


      def insert_page(index, child_page, box = nil)
        child_page.container = self
        if page
          child_page.depth = page.depth + 1
          page.children << child_page
          child_page.parent = page
          child_page.update_path
        end
        insert_with_style(:page, index, child_page, box)
      end

      def insert_piece(index, piece, box = nil)
        piece.container = self
        piece.page = page if page
        piece.depth = (depth || 0) + 1
        insert_with_style(:piece, index, piece, box)
      end

      def insert_with_style(type, index, content, box = nil)
        entry_style = style_for_content(content, box)
        content._prototype = box.prototype_for_content(content) if box
        entry = Spontaneous::Entry.send(type, self, content, entry_style, box)
        begin
          entries.insert(index, entry)
        rescue TypeError, RuntimeError => e
          # TODO: raise a custom more helpful error here
          logger.error { "Attempting to modify visible only entries" }
          raise e
        end

        entry
      end

      def update_position(position)
        container.entries.set_position(self, position)
        container.save
      end

      def style_for_content(content, box = nil)
        if box
          box.style_for_content(content)
        else
          content.styles.default
        end
      end

      def available_styles(content)
        content.styles
      end

      def entry=(entry)
        @entry = entry
      end

      def entry
        @entry ||= resolve_entry
      end

      def container=(container)
        super
        self[:content_path] = [container.content_path, container.id].compact.join(CONTENT_PATH_SEP)
      end

      def resolve_entry
        container.all_entries.find { |e| e.target_id == self.id }
      end

      protected(:resolve_entry)

      def method_missing(method, *args)
        if entry = entries.labelled(method)
          entry
        else
          super
        end
      end
    end # InstanceMethods
  end # Entries
end # Spontaneous::Plugins

