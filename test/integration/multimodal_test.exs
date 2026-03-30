Code.require_file("test_helper.exs", __DIR__)

defmodule ExOutlines.Integration.MultimodalTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias ExOutlines.{Backend.Anthropic, Backend.HTTP, IntegrationTestHelper}
  alias ExOutlines.Spec.Schema

  @test_image_url "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Raspberry-pi-4-model-b.jpg/320px-Raspberry-pi-4-model-b.jpg"

  @small_base64_image "iVBORwD/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP///yH5BAEAAH8ALAAAAAAQABAAAAfMgH+gOEGh4eIMCIzDjAdE4ijFZqYKpBJCzR0dHR0dEoXDUkLDQ0NFQ0JdQoxHBsFagUBkYJEBQAQCAoKDUkOBGQFagUlVwQFagQCAgMCAgECAgECAQoEBYoJKAQoKAgYKBQoKCgoICgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCv/bAIQABgQEBAUEBgQEBgkGBQYIBgYJDQsIBgYNDQ0NDg4SFBQUEBMcFxgWGRgYGBcgHBwcHBYgICUhHx8dCiQdHyEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEh/8AAEQgAAQABAwEiAAIRAQMRAf/aAAgBAQABPxA+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp8+nz6fPp//9k="

  describe "OpenAI multimodal" do
    @tag :openai_multimodal
    test "image_url content with OpenAI" do
      skip_if_no_api_key("OPENAI_API_KEY")

      api_key = IntegrationTestHelper.get_api_key("OPENAI_API_KEY")

      schema =
        Schema.new(%{
          description: %{type: :string, required: true}
        })

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: HTTP,
                 backend_opts: [api_key: api_key, model: "gpt-4o-mini"],
                 content: [
                   %{
                     type: :text,
                     text: "What is shown in this image? Provide a brief description."
                   },
                   %{type: :image_url, url: @test_image_url}
                 ],
                 max_retries: 2
               )

      assert is_binary(result.description)
      assert String.length(result.description) > 10
    end

    @tag :openai_multimodal
    test "image_base64 content with OpenAI" do
      skip_if_no_api_key("OPENAI_API_KEY")

      api_key = IntegrationTestHelper.get_api_key("OPENAI_API_KEY")

      schema =
        Schema.new(%{
          items_count: %{type: :integer, required: true}
        })

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: HTTP,
                 backend_opts: [api_key: api_key, model: "gpt-4o-mini"],
                 content: [
                   %{type: :text, text: "Count the items in this simple image. Return the count."},
                   %{type: :image_base64, data: @small_base64_image, media_type: "image/jpeg"}
                 ],
                 max_retries: 2
               )

      assert is_integer(result.items_count)
    end
  end

  describe "Anthropic multimodal" do
    @tag :anthropic_multimodal
    test "image_url content with Anthropic" do
      skip_if_no_api_key("ANTHROPIC_API_KEY")

      api_key = IntegrationTestHelper.get_api_key("ANTHROPIC_API_KEY")

      schema =
        Schema.new(%{
          description: %{type: :string, required: true}
        })

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Anthropic,
                 backend_opts: [api_key: api_key],
                 content: [
                   %{
                     type: :text,
                     text: "What is shown in this image? Provide a brief description."
                   },
                   %{type: :image_url, url: @test_image_url}
                 ],
                 max_retries: 2
               )

      assert is_binary(result.description)
      assert String.length(result.description) > 10
    end

    @tag :anthropic_multimodal
    test "image_base64 content with Anthropic" do
      skip_if_no_api_key("ANTHROPIC_API_KEY")

      api_key = IntegrationTestHelper.get_api_key("ANTHROPIC_API_KEY")

      schema =
        Schema.new(%{
          color: %{type: :string, required: true}
        })

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Anthropic,
                 backend_opts: [api_key: api_key],
                 content: [
                   %{type: :text, text: "What is the dominant color in this image?"},
                   %{type: :image_base64, data: @small_base64_image, media_type: "image/jpeg"}
                 ],
                 max_retries: 2
               )

      assert is_binary(result.color)
    end
  end

  describe "mixed content types" do
    @tag :openai_multimodal
    test "multiple text and image parts" do
      skip_if_no_api_key("OPENAI_API_KEY")

      api_key = IntegrationTestHelper.get_api_key("OPENAI_API_KEY")

      schema =
        Schema.new(%{
          analysis: %{type: :string, required: true}
        })

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: HTTP,
                 backend_opts: [api_key: api_key, model: "gpt-4o-mini"],
                 content: [
                   %{type: :text, text: "First, analyze this image."},
                   %{type: :image_url, url: @test_image_url},
                   %{type: :text, text: "Provide a summary of key components."}
                 ],
                 max_retries: 2
               )

      assert is_binary(result.analysis)
    end
  end

  defp skip_if_no_api_key(env_var) do
    unless System.get_env(env_var) do
      throw({:skip_test, "#{env_var} not set - skipping multimodal test"})
    end
  end
end
