module TextEngineT

include("EngineT.jl")
include("BertInteractions.jl")

using .EngineT
using .BertInteractions

export Engine, encode_text, decode_tokens, get_embeddings, analyze_context,
    check_hf_functions, show_engine_info, test_tokenizer, test_model, example_usage,
    text_similarity, batch_similarity, find_most_similar, find_least_similar,
    semantic_distance, cosine_similarity, euclidean_similarity,
    semantic_search, find_best_matches, rank_documents, search_threshold,
    fuzzy_semantic_search, multi_query_search,
    classify_sentiment, classify_by_examples, nearest_neighbor_classify,
    cluster_texts, find_outliers, group_similar_texts,
    analyze_text_complexity, compare_writing_styles, detect_topics,
    measure_coherence, find_key_phrases, analyze_readability,
    create_text_database, batch_process_texts, similarity_matrix,
    text_to_vector, normalize_embeddings, reduce_dimensions

end # module TextEngineT
