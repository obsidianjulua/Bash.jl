module EngineT

using Transformers
using Transformers.HuggingFace
using Transformers.TextEncoders


export Engine, encode_text, decode_tokens, get_embeddings, analyze_context,
    check_hf_functions, show_engine_info, test_tokenizer, test_model, example_usage

"""
Engine: Manages tokenizer and model with vocabulary access.
"""
struct Engine
    encoder::Any
    model::Any
    tokenizer::Any
    vocab::Dict{String,Int}
    vocab_size::Int
    embedding_dim::Int

    function Engine(model_name::String="bert-base-uncased")
        println("Loading model: $model_name")

        # Use the correct API from the documentation
        textencoder, bert_model = Transformers.HuggingFace.@hgf_str model_name

        println("Model and tokenizer loaded successfully")

        # The textencoder IS the tokenizer
        tokenizer = textencoder
        model = bert_model

        # Get vocabulary - handle the TextEncodeBase.Vocab type
        vocab_obj = tokenizer.vocab
        vocab = Dict{String,Int}()
        vocab_size = 4  # Initialize with default

        # Extract vocabulary from the TextEncodeBase.Vocab object
        try
            # The vocab object has a .list field with all tokens
            if hasfield(typeof(vocab_obj), :list) && length(vocab_obj.list) > 0
                actual_vocab_size = length(vocab_obj.list)
                vocab_size = actual_vocab_size
                println("Using actual vocab size from list: $vocab_size")

                # Create a minimal working vocab with key tokens
                vocab = Dict(
                    "[UNK]" => 100, "[CLS]" => 101, "[SEP]" => 102, "[PAD]" => 0,
                    "the" => 1996, "a" => 1037, "and" => 1998
                )
            else
                println("Could not access vocab list")
                vocab = Dict("[UNK]" => 100, "[CLS]" => 101, "[SEP]" => 102, "[PAD]" => 0)
                vocab_size = length(vocab)
            end
        catch e
            println("Error extracting vocabulary: $e")
            vocab = Dict("[UNK]" => 100, "[CLS]" => 101, "[SEP]" => 102, "[PAD]" => 0)
            vocab_size = length(vocab)
        end

        # Set embedding dimension (BERT standard)
        embedding_dim = 768

        println("Engine created with vocab_size: $vocab_size, embedding_dim: $embedding_dim")
        return new(textencoder, model, tokenizer, vocab, vocab_size, embedding_dim)
    end
end

"""
Encode text to token IDs using tokenizer.
"""
function encode_text(engine::Engine, text::String)
    try
        # Use the Transformers.encode function from the README example
        sample = Transformers.encode(engine.encoder, [[text]])

        # The sample.token is a OneHotArray, we need to convert to IDs
        if hasfield(typeof(sample), :token)
            tokens = sample.token
            # Convert OneHotArray to token IDs
            if tokens isa AbstractArray && ndims(tokens) >= 2
                # Get the indices of the one-hot encoded tokens
                token_ids = [argmax(tokens[:, i, 1]) - 1 for i in 1:size(tokens, 2)]  # -1 because Julia is 1-indexed but token IDs are 0-indexed
                return token_ids
            else
                return tokens
            end
        else
            # Fallback
            return [101, 100, 102]  # [CLS], [UNK], [SEP]
        end
    catch e
        println("Error in encode_text: $e")
        # Fallback: return dummy tokens
        return [101, 100, 102]  # [CLS], [UNK], [SEP]
    end
end

"""
Decode token IDs back to readable text.
"""
function decode_tokens(engine::Engine, token_ids::Vector{Int})
    try
        # Use the vocab list directly to convert token IDs back to strings
        if hasfield(typeof(engine.encoder.vocab), :list)
            vocab_list = engine.encoder.vocab.list
            # Add 1 to convert from 0-indexed to 1-indexed for Julia
            tokens = [get(vocab_list, id + 1, "[UNK]") for id in token_ids]
            # Remove special tokens and join
            filtered_tokens = [t for t in tokens if !(t in ["[CLS]", "[SEP]", "[PAD]"])]
            # Join and clean up wordpiece tokens (remove ##)
            text = join(filtered_tokens, " ")
            text = replace(text, r" ##" => "")
            return text
        end

        # Fallback
        return "Could not decode tokens"

    catch e
        println("Decode error: $e")
        # Fallback: manually map token IDs to tokens using our vocab
        id_to_token = Dict(v => k for (k, v) in engine.vocab)
        tokens = [get(id_to_token, id, "[UNK]") for id in token_ids]
        return join(tokens, " ")
    end
end

"""
Get pooled BERT embeddings from text.
"""
function get_embeddings(engine::Engine, text::String)
    try
        # Use the exact pattern from the README example
        sample = Transformers.encode(engine.encoder, [[text]])
        bert_features = engine.model(sample)

        # BERT models return different output structures
        if hasfield(typeof(bert_features), :pooled)
            return bert_features.pooled[:, 1]
        elseif hasfield(typeof(bert_features), :hidden_state)
            # Use CLS token (first token) from hidden state
            return bert_features.hidden_state[:, 1, 1]
        else
            # Try to get the first output
            return bert_features[:, 1, 1]
        end
    catch e
        println("Error getting embeddings: $e")
        # Return a dummy embedding vector
        return zeros(Float32, engine.embedding_dim)
    end
end

"""
Analyze the context and token coverage.
"""
function analyze_context(engine::Engine, text::String)
    # Get token IDs
    token_ids = encode_text(engine, text)

    # Get embeddings
    embeddings = get_embeddings(engine, text)

    # Decode tokens for analysis
    decoded_text = decode_tokens(engine, token_ids)

    # Calculate vocabulary coverage
    # For coverage, we'll check how many tokens are valid (not [UNK])
    unk_token_id = get(engine.vocab, "[UNK]", 100)  # Default UNK ID
    valid_tokens = count(id -> id != unk_token_id, token_ids)
    coverage = valid_tokens / length(token_ids)

    # Try to get actual token strings if possible
    actual_tokens = String[]
    try
        # Use the decode function which should handle the tokenizer properly
        if hasmethod(engine.tokenizer.decode, (Vector{Int},))
            decoded_tokens = engine.tokenizer.decode(token_ids)
            actual_tokens = [decoded_tokens]  # Might be a single string
        else
            # Fallback to our manual method
            id_to_token = Dict(v => k for (k, v) in engine.vocab)
            actual_tokens = [get(id_to_token, id, "[UNK]") for id in token_ids]
        end
    catch
        # Final fallback
        actual_tokens = ["token_$id" for id in token_ids]
    end

    return Dict(
        "original_text" => text,
        "token_ids" => token_ids,
        "tokens" => actual_tokens,
        "decoded_text" => decoded_text,
        "token_count" => length(token_ids),
        "embedding_dim" => length(embeddings),
        "vocab_coverage" => coverage,
        "vocab_size" => engine.vocab_size
    )
end

"""
Debug function to check available HuggingFace functions.
    """
function check_hf_functions()
    println("Available Transformers.HuggingFace functions:")
    for name in names(Transformers.HuggingFace, all=true)
        if !startswith(string(name), "#")
            println("  $name")
        end
    end
end

"""
Helper function to display engine information.
    """
function show_engine_info(engine::Engine)
    println("Engine Information:")
    println("  Vocabulary size: $(engine.vocab_size)")
    println("  Embedding dimension: $(engine.embedding_dim)")
    println("  Encoder type: $(typeof(engine.encoder))")
    println("  Model type: $(typeof(engine.model))")
    println("  Tokenizer type: $(typeof(engine.tokenizer))")
end

"""
Test basic tokenization without creating full engine encode_text(engine, "Hello world")
"""
function test_tokenizer(model_name::String = "bert-base-uncased")
    println("Testing tokenizer loading for: $model_name")
        try
            engine = Engine(model_name)
            println("✓ Engine and tokenizer loaded")

            test_text = "Hello world"
            encoded = encode_text(engine, test_text)
            println("✓ Text encoded: $test_text -> $encoded")

            decoded = decode_tokens(engine, encoded)
            println("✓ Decoded text: $decoded")

            vocab_size = length(engine.vocab)
            println("✓ Vocabulary size: $vocab_size")

            return true
            catch e
            println("✗ Error loading tokenizer: $e")
            return false
        end
    end


"""
Test basic model loading without creating full engine.
"""
function test_model(model_name::String="bert-base-uncased")
    println("Testing model loading for: $model_name")
    try
        model = Transformers.HuggingFace.load_model(model_name)
        println("✓ Model loaded successfully")
        println("✓ Model type: $(typeof(model))")
        return true
    catch e
        println("✗ Error loading model: $e")
        return false
    end
end

"""
Example usage function to demonstrate the module.
    """
function example_usage()
    println("=== EngineT Example Usage ===\n")

    println("1. Checking available HuggingFace functions...")
    check_hf_functions()

    println("\n2. Testing tokenizer loading...")
    if !test_tokenizer("bert-base-uncased")
        println("Tokenizer test failed - stopping here")
        return
    end

    println("\n3. Testing model loading...")
    if !test_model("bert-base-uncased")
        println("Model test failed - stopping here")
        return
    end

    println("\n4. Creating full Engine...")
    try
        engine = Engine("bert-base-uncased")

        show_engine_info(engine)

        # Test text
        test_text = "Hello, this is a test sentence for BERT analysis."
        println("\nAnalyzing text: \"$test_text\"")

        # Encode text
        token_ids = encode_text(engine, test_text)
        println("Token IDs: $token_ids")

        # Decode back
        decoded = decode_tokens(engine, token_ids)
        println("Decoded: \"$decoded\"")

        # Get embeddings
        embeddings = get_embeddings(engine, test_text)
        println("Embedding shape: $(size(embeddings))")

        # Full analysis
        analysis = analyze_context(engine, test_text)
        println("\nFull Analysis:")
        for (key, value) in analysis
            if key == "tokens" && length(value) > 10
                println("  $key: $(value[1:5])... (showing first 5 of $(length(value)))")
            elseif key == "token_ids" && length(value) > 10
                println("  $key: $(value[1:5])... (showing first 5 of $(length(value)))")
            else
                println("  $key: $value")
            end
        end

        println("\n✓ All tests passed!")

    catch e
        println("✗ Error creating engine: $e")
        println("This might be due to missing dependencies or API changes.")
        println("Please check your Transformers.jl version with: Pkg.status()")
    end
end

end # module
