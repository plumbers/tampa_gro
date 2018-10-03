json_response do
  {
      encryption_key: @key.random_key,
      encryption_key_version: @key.key_version
  }
end
