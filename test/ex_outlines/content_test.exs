defmodule ExOutlines.ContentTest do
  use ExUnit.Case, async: true

  alias ExOutlines.Backend.Mock
  alias ExOutlines.Content
  alias ExOutlines.Spec.Schema

  doctest ExOutlines.Content

  describe "text/1" do
    test "creates text content part" do
      assert %{type: :text, text: "hello"} = Content.text("hello")
    end
  end

  describe "image_url/1" do
    test "creates image URL content part" do
      part = Content.image_url("https://example.com/photo.jpg")
      assert %{type: :image_url, url: "https://example.com/photo.jpg"} = part
    end
  end

  describe "image_base64/2" do
    test "creates base64 image content part" do
      part = Content.image_base64("iVBOR...", "image/png")
      assert %{type: :image_base64, data: "iVBOR...", media_type: "image/png"} = part
    end
  end

  describe "image_file/1" do
    setup do
      dir = System.tmp_dir!()
      path = Path.join(dir, "test_image_#{System.unique_integer([:positive])}.png")
      File.write!(path, "fake png data")
      on_exit(fn -> File.rm(path) end)
      %{path: path}
    end

    test "reads file and creates base64 content part", %{path: path} do
      part = Content.image_file(path)
      assert %{type: :image_base64, media_type: "image/png"} = part
      assert part.data == Base.encode64("fake png data")
    end

    test "infers media type from extension" do
      dir = System.tmp_dir!()
      uid = System.unique_integer([:positive])

      for {ext, expected_type} <- [
            {".jpg", "image/jpeg"},
            {".jpeg", "image/jpeg"},
            {".gif", "image/gif"},
            {".webp", "image/webp"}
          ] do
        path = Path.join(dir, "test_#{uid}#{ext}")
        File.write!(path, "data")
        on_exit(fn -> File.rm(path) end)
        part = Content.image_file(path)
        assert part.media_type == expected_type
      end
    end

    test "raises on unsupported extension" do
      dir = System.tmp_dir!()
      path = Path.join(dir, "test_#{System.unique_integer([:positive])}.bmp")
      File.write!(path, "data")
      on_exit(fn -> File.rm(path) end)

      assert_raise ArgumentError, ~r/unsupported image extension/, fn ->
        Content.image_file(path)
      end
    end
  end

  describe "generate/2 with :content option" do
    test "passes multimodal content through to messages" do
      mock = Mock.new([{:ok, ~s({"label": "receipt"})}])
      schema = Schema.new(%{label: %{type: :string, required: true}})

      result =
        ExOutlines.generate(schema,
          backend: Mock,
          backend_opts: [mock: mock],
          content: [
            Content.text("What is this?"),
            Content.image_base64("data", "image/png")
          ]
        )

      assert {:ok, %{label: "receipt"}} = result
    end

    test "rejects combining template and content" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, :template_and_content_conflict} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: Mock.new([])],
                 template: {"hello", []},
                 content: [Content.text("hi")]
               )
    end

    test "rejects invalid content option" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, {:invalid_content, "not a list"}} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: Mock.new([])],
                 content: "not a list"
               )
    end

    test "rejects empty content list" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, {:invalid_content, []}} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: Mock.new([])],
                 content: []
               )
    end

    test "rejects malformed content parts" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, {:invalid_content, _}} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: Mock.new([])],
                 content: [%{bad: "part"}]
               )
    end

    test "works without content (backward compatible)" do
      mock = Mock.new([{:ok, ~s({"name": "Alice"})}])
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:ok, %{name: "Alice"}} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )
    end
  end

  describe "Prompt.build_initial_with_content/2" do
    test "includes content parts in user message" do
      schema = Schema.new(%{label: %{type: :string, required: true}})

      parts = [
        Content.text("Describe this:"),
        Content.image_base64("abc", "image/png")
      ]

      messages = ExOutlines.Prompt.build_initial_with_content(schema, parts)

      assert [system_msg, user_msg] = messages
      assert system_msg.role == "system"
      assert is_binary(system_msg.content)

      assert user_msg.role == "user"
      assert is_list(user_msg.content)

      # Should have: text part, image part, schema text part
      assert length(user_msg.content) == 3
      assert %{type: :text, text: "Describe this:"} = Enum.at(user_msg.content, 0)
      assert %{type: :image_base64} = Enum.at(user_msg.content, 1)
      assert %{type: :text, text: schema_text} = Enum.at(user_msg.content, 2)
      assert schema_text =~ "Generate JSON output"
    end
  end
end
