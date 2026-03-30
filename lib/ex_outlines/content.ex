defmodule ExOutlines.Content do
  @moduledoc """
  Helpers for building multimodal content parts.

  Used with the `:content` option in `ExOutlines.generate/2` to include
  images alongside text prompts for vision-capable models.

  ## Example

      alias ExOutlines.Content

      ExOutlines.generate(schema,
        backend: backend,
        backend_opts: opts,
        content: [
          Content.text("Extract data from this receipt:"),
          Content.image_file("/path/to/receipt.png")
        ]
      )
  """

  @type content_part :: ExOutlines.Backend.content_part()

  @doc """
  Create a text content part.

  ## Examples

      iex> ExOutlines.Content.text("Hello")
      %{type: :text, text: "Hello"}
  """
  @spec text(String.t()) :: content_part()
  def text(value) when is_binary(value) do
    %{type: :text, text: value}
  end

  @doc """
  Create an image content part from a URL.

  ## Examples

      iex> ExOutlines.Content.image_url("https://example.com/photo.jpg")
      %{type: :image_url, url: "https://example.com/photo.jpg"}
  """
  @spec image_url(String.t()) :: content_part()
  def image_url(url) when is_binary(url) do
    %{type: :image_url, url: url}
  end

  @doc """
  Create an image content part from a base64-encoded string.

  ## Parameters

  - `data` - Base64-encoded image data
  - `media_type` - MIME type (e.g., `"image/png"`, `"image/jpeg"`)

  ## Examples

      iex> ExOutlines.Content.image_base64("iVBOR...", "image/png")
      %{type: :image_base64, data: "iVBOR...", media_type: "image/png"}
  """
  @spec image_base64(String.t(), String.t()) :: content_part()
  def image_base64(data, media_type)
      when is_binary(data) and is_binary(media_type) do
    %{type: :image_base64, data: data, media_type: media_type}
  end

  @doc """
  Create an image content part from a local file.

  Reads the file, base64-encodes it, and infers the media type from the extension.

  Supported extensions: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`.
  """
  @spec image_file(Path.t()) :: content_part()
  def image_file(path) when is_binary(path) do
    data = File.read!(path)
    media_type = media_type_for(path)
    image_base64(Base.encode64(data), media_type)
  end

  defp media_type_for(path) do
    case Path.extname(path) |> String.downcase() do
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ext -> raise ArgumentError, "unsupported image extension: #{ext}"
    end
  end
end
