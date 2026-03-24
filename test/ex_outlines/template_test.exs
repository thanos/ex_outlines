defmodule ExOutlines.TemplateTest do
  use ExUnit.Case, async: true

  alias ExOutlines.Template
  alias ExOutlines.Spec.Schema

  describe "render/2" do
    test "renders template with assigns" do
      result = Template.render("Hello, <%= @name %>!", name: "World")
      assert result == "Hello, World!"
    end

    test "renders template without assigns" do
      result = Template.render("Static text")
      assert result == "Static text"
    end

    test "renders template with list assigns" do
      template = "Items: <%= Enum.join(@items, \", \") %>"
      result = Template.render(template, items: ["a", "b", "c"])
      assert result == "Items: a, b, c"
    end

    test "renders template with conditional logic" do
      template = "<%= if @verbose do %>Detailed<% else %>Brief<% end %>"
      assert Template.render(template, verbose: true) == "Detailed"
      assert Template.render(template, verbose: false) == "Brief"
    end

    test "renders template with iteration" do
      template = """
      <%= for {label, value} <- @examples do %>\
      <%= label %>: <%= value %>
      <% end %>\
      """

      result = Template.render(template, examples: [{"Positive", "great"}, {"Negative", "bad"}])
      assert result =~ "Positive: great"
      assert result =~ "Negative: bad"
    end

    test "returns empty string for missing assigns" do
      # EEx returns empty/nil for missing assigns with a warning
      result = Template.render("Hello, <%= @missing %>!", [])
      assert is_binary(result)
    end
  end

  describe "render_file/2" do
    setup do
      dir = System.tmp_dir!()
      path = Path.join(dir, "test_template_#{System.unique_integer([:positive])}.eex")

      on_cleanup = fn -> File.rm(path) end

      %{path: path, cleanup: on_cleanup}
    end

    test "renders template from file", %{path: path, cleanup: cleanup} do
      File.write!(path, "Hello, <%= @name %>!")
      result = Template.render_file(path, name: "File")
      assert result == "Hello, File!"
      cleanup.()
    end

    test "raises on missing file" do
      assert_raise File.Error, fn ->
        Template.render_file("/nonexistent/path.eex", [])
      end
    end
  end

  describe "build_messages/3" do
    test "builds messages with rendered template as user content" do
      template = "Extract medical data from: <%= @text %>"
      assigns = [text: "Patient has fever of 101F"]
      schema = Schema.new(%{diagnosis: %{type: :string, required: true}})

      messages = Template.build_messages(template, assigns, schema)

      assert length(messages) == 2
      assert Enum.at(messages, 0).role == "system"
      assert Enum.at(messages, 0).content =~ "structured data generator"
      assert Enum.at(messages, 1).role == "user"
      assert Enum.at(messages, 1).content =~ "Extract medical data from: Patient has fever of 101F"
      assert Enum.at(messages, 1).content =~ "diagnosis"
    end

    test "includes JSON schema in user message" do
      template = "Classify: <%= @input %>"
      schema = Schema.new(%{category: %{type: {:enum, ["positive", "negative"]}, required: true}})

      messages = Template.build_messages(template, [input: "great product"], schema)
      user_content = Enum.at(messages, 1).content

      assert user_content =~ "Classify: great product"
      assert user_content =~ "positive"
      assert user_content =~ "negative"
    end
  end

  describe "generate/2 template validation" do
    test "rejects invalid template option (bare string)" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, {:invalid_template, "not a tuple"}} =
               ExOutlines.generate(schema,
                 backend: ExOutlines.Backend.Mock,
                 backend_opts: [mock: ExOutlines.Backend.Mock.new([])],
                 template: "not a tuple"
               )
    end

    test "rejects invalid template option (wrong tuple shape)" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, {:invalid_template, {123, []}}} =
               ExOutlines.generate(schema,
                 backend: ExOutlines.Backend.Mock,
                 backend_opts: [mock: ExOutlines.Backend.Mock.new([])],
                 template: {123, []}
               )
    end

    test "rejects invalid template option (assigns not a list)" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, {:invalid_template, {"<%= @x %>", %{x: 1}}}} =
               ExOutlines.generate(schema,
                 backend: ExOutlines.Backend.Mock,
                 backend_opts: [mock: ExOutlines.Backend.Mock.new([])],
                 template: {"<%= @x %>", %{x: 1}}
               )
    end
  end

  describe "integration with ExOutlines.generate/2" do
    test "template option is passed through to generation" do
      alias ExOutlines.Backend.Mock

      mock = Mock.new([{:ok, ~s({"name": "Alice"})}])
      schema = Schema.new(%{name: %{type: :string, required: true}})
      template = "Extract the name from: <%= @text %>"

      result =
        ExOutlines.generate(schema,
          backend: Mock,
          backend_opts: [mock: mock],
          template: {template, [text: "My name is Alice"]}
        )

      assert {:ok, %{name: "Alice"}} = result
    end

    test "generation works without template (backward compatible)" do
      alias ExOutlines.Backend.Mock

      mock = Mock.new([{:ok, ~s({"name": "Bob"})}])
      schema = Schema.new(%{name: %{type: :string, required: true}})

      result =
        ExOutlines.generate(schema,
          backend: Mock,
          backend_opts: [mock: mock],
          max_retries: 1
        )

      assert {:ok, %{name: "Bob"}} = result
    end
  end
end
