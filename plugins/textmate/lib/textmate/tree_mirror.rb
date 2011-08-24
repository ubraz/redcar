module Redcar
  module Textmate
    TREE_TITLE = "Bundles"

    # Some Icons by Yusuke Kamiyamane.
    # http://p.yusukekamiyamane.com/
    #
    # Licensed under a Creative Commons Attribution 3.0 license.
    # http://creativecommons.org/licenses/by/3.0/
    class TreeController
      include Redcar::Tree::Controller

      def right_click(tree, node)
        controller = self
        menu = Menu.new
        Redcar.plugin_manager.objects_implementing(:bundle_context_menus).each do |object|
          case object.method(:bundle_context_menus).arity
          when 1
            menu.merge(object.bundle_context_menus(node))
          when 2
            menu.merge(object.bundle_context_menus(tree, node))
          when 3
            menu.merge(object.bundle_context_menus(tree, node, controller))
          else
            puts("Invalid bundle_context_menus hook detected in "+object.class.name)
          end
        end
        Application::Dialog.popup_menu(menu, :pointer)
      end

      def activated(tree, node)
        if node.leaf? and
            tab = Redcar.app.focussed_notebook_tab and
            tab.is_a?(EditTab)
          doc = tab.document
          if tab.edit_tab? and doc
            controller = doc.controllers(Snippets::DocumentController).first
            controller.start_snippet!(node.snippet)
            tab.focus
          end
        end
      end
    end

    class TreeMirror
      include Redcar::Tree::Mirror

      def initialize(bundles)
        @top = []
        bundles.sort_by {|bundle| (bundle.name||"").downcase}.each_with_index do |b, i|
          if b.name and b.snippets #and b.snippets.size() > 0
            name = b.name.downcase
            unless Textmate.storage['select_bundles_for_tree'] and
              !Textmate.storage['loaded_bundles'].to_a.include?(name)
              @top << BundleNode.new(b)
            end
          end
        end

        if @top.size() < 1
          @top = [EmptyTree.new]
        end
      end

      def refresh(bundle_names = nil)
        if bundle_names
          bundle_names.each do |name|
            node = @top.detect {|n| n.text == name }
            node.refresh if node
          end
        end
        cache = []
        cache.concat(@top)
        @top = []
        @top.concat(cache)
        cache = nil
      end

      def title
        TREE_TITLE
      end

      def top
        @top
      end
    end

    class EmptyTree
      include Redcar::Tree::Mirror::NodeMirror
      def text
        "No snippets found"
      end
    end

    class BundleNode
      include Redcar::Tree::Mirror::NodeMirror
      attr_reader :bundle

      def initialize(bundle)
        @bundle = bundle
        @children = nil
      end

      def leaf?
        false
      end

      def text
        @bundle.name
      end

      def refresh
        @children = nil
      end

      def children
        @children ||= begin
          children = []
          if @bundle.main_menu and @bundle.main_menu['items']
            @bundle.main_menu["items"].each do |item|
              build_children(children, @bundle, item, self)
            end
          end
          children
        end
      end

      def icon
        if Textmate.storage['loaded_bundles'].include?(text.downcase)
          :"ui-menu-blue"
        else
          :"document-tree"
        end
      end

      private

      def build_children(list, bundle, item, parent_node)
        #if item is a snippet, add to list
        if snippet = Textmate.uuid_hash[item] and snippet.is_a?(Textmate::Snippet)
          return unless snippet.name and snippet.name != ""
          list << SnippetNode.new(snippet,parent_node)
        #if item has submenus, make a group and add sub-items
        elsif sub_menu = bundle.sub_menus[item]
          group = SnippetGroup.new(sub_menu["name"],item,bundle,parent_node)
          if sub_menu["items"] and sub_menu["items"].size > 0
            sub_menu["items"].each do |sub_item|
              build_children(group.children, bundle, sub_item, group)
            end
          end
          list << group
        end
      end
    end

    class SnippetGroup
      include Redcar::Tree::Mirror::NodeMirror

      attr_writer :children
      attr_reader :uuid,:bundle,:parent

      def initialize(name,uuid,bundle,parent)
        @children = []
        @text     = name
        @bundle   = bundle
        @uuid     = uuid
        @parent   = parent
      end

      def icon
        :"document-tree"
      end

      def leaf?
        false
      end

      def text
        @text
      end

      def children
        @children
      end
    end

    class SnippetNode
      include Redcar::Tree::Mirror::NodeMirror

      attr_reader :parent, :snippet

      def initialize(snippet,parent)
        @snippet = snippet
        @parent = parent
      end

      def icon
        :"document-snippet"
      end

      def text
        name = @snippet.name.clone
        if t = @snippet.tab_trigger
          name << " (#{t})"
        end
        name
      end

      def leaf?
        true
      end

      def children
        []
      end

      def snippet
        @snippet
      end
    end
  end
end
