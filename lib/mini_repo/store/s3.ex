defmodule MiniRepo.Store.S3 do
  @moduledoc """
  S3 storage.

  ## Options

    * `:bucket` - the S3 bucket
    * `:options` - the S3 request options [(most options are listed in this module)](https://github.com/ex-aws/ex_aws/blob/master/lib/ex_aws/config.ex)

  ## Usage

  Add to `config/releases.exs`:

      config :ex_aws,
        access_key_id: System.fetch_env!("MINI_REPO_S3_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("MINI_REPO_S3_SECRET_ACCESS_KEY"),
        json_codec: Jason

      store =
        {MiniRepo.Store.S3,
         bucket: System.fetch_env!("MINI_REPO_S3_BUCKET"),
         options: [
           region: System.fetch_env!("MINI_REPO_S3_REGION")]
         }

  And configure your repositories with the given store, e.g.:

      config :mini_repo,
        repositories: [
          myrepo: [
            store: store,
            # ...
          ]

  Finally, by default, the files stored on S3 are not publicly accessible.
  You can enable public access by setting following bucket policy in your
  bucket's properties:

  ```json
  {
      "Version": "2008-10-17",
      "Statement": [
          {
              "Sid": "AllowPublicRead",
              "Effect": "Allow",
              "Principal": {
                  "AWS": "*"
              },
              "Action": "s3:GetObject",
              "Resource": "arn:aws:s3:::minirepo/*"
          }
      ]
  }
  ```

  Since we're storing files on S3, in order to access the repo we can use the publicly
  accessible URL of the bucket:

      mix hex.repo add myrepo https://<bucket>.s3.<region>.amazonaws.com/repos/myrepo --public-key $MINI_REPO_PUBLIC_KEY

  See [Amazon S3 docs](https://docs.aws.amazon.com/s3/index.html) for more information.
  """

  @behaviour MiniRepo.Store

  alias ExAws.S3

  defstruct [:bucket, :options]

  @impl true
  def put(key, value, options, state) do
    key = Path.join(List.wrap(key))
    request = S3.put_object(state.bucket, key, value, options)

    with {:ok, _} <- ExAws.request(request, state.options) do
      :ok
    end
  end

  @impl true
  def fetch(key, options, state) do
    key = Path.join(List.wrap(key))
    request = S3.get_object(state.bucket, key, options)

    case ExAws.request(request, state.options) do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}

      other ->
        other
    end
  end

  @impl true
  def delete(key, options, state) do
    key = Path.join(List.wrap(key))
    request = S3.delete_object(state.bucket, key, options)

    with {:ok, _} <- ExAws.request(request, state.options) do
      :ok
    end
  end
end
