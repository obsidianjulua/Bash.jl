module BertInteractions

using ..EngineT                 # ✅ preferred when loading from TextEngineT.jl
using LinearAlgebra
using Statistics
using StatsBase

export
    # Similarity Functions
    text_similarity, batch_similarity, find_most_similar, find_least_similar,
    semantic_distance, cosine_similarity, euclidean_similarity,

    # Search & Retrieval
    semantic_search, find_best_matches, rank_documents, search_threshold,
    fuzzy_semantic_search, multi_query_search,

    # Classification & Clustering
    classify_sentiment, classify_by_examples, nearest_neighbor_classify,
    cluster_texts, find_outliers, group_similar_texts,

    # Text Analysis
    analyze_text_complexity, compare_writing_styles, detect_topics,
    measure_coherence, find_key_phrases, analyze_readability,

    # Utilities
    create_text_database, batch_process_texts, similarity_matrix,
    text_to_vector, normalize_embeddings, reduce_dimensions

"""
Calculate cosine similarity between two texts.
"""
function text_similarity(engine, text1::String, text2::String)
    emb1 = get_embeddings(engine, text1)
    emb2 = get_embeddings(engine, text2)
    return dot(emb1, emb2) / (norm(emb1) * norm(emb2))
end

"""
Calculate similarity between one text and multiple texts.
"""
function batch_similarity(engine, reference::String, texts::Vector{String})
    ref_emb = get_embeddings(engine, reference)
    similarities = Float64[]

    for text in texts
        text_emb = get_embeddings(engine, text)
        sim = dot(ref_emb, text_emb) / (norm(ref_emb) * norm(text_emb))
        push!(similarities, sim)
    end

    return similarities
end

"""
Find the most similar text from a collection.
"""
function find_most_similar(engine, query::String, candidates::Vector{String})
    similarities = batch_similarity(engine, query, candidates)
    best_idx = argmax(similarities)
    return candidates[best_idx], similarities[best_idx], best_idx
end

"""
Find the least similar text from a collection.
"""
function find_least_similar(engine, query::String, candidates::Vector{String})
    similarities = batch_similarity(engine, query, candidates)
    worst_idx = argmin(similarities)
    return candidates[worst_idx], similarities[worst_idx], worst_idx
end

"""
Calculate semantic distance (inverse of similarity).
"""
function semantic_distance(engine, text1::String, text2::String)
    return 1.0 - text_similarity(engine, text1, text2)
end

"""
Cosine similarity with explicit name.
"""
cosine_similarity(engine, text1::String, text2::String) = text_similarity(engine, text1, text2)

"""
Euclidean similarity between embeddings.
"""
function euclidean_similarity(engine, text1::String, text2::String)
    emb1 = get_embeddings(engine, text1)
    emb2 = get_embeddings(engine, text2)
    distance = norm(emb1 - emb2)
    return 1.0 / (1.0 + distance)  # Convert distance to similarity
end

"""
Semantic search: find documents most relevant to a query.
"""
function semantic_search(engine, query::String, documents::Vector{String}; top_k=5)
    similarities = batch_similarity(engine, query, documents)

    # Get top-k results
    sorted_indices = sortperm(similarities, rev=true)
    top_indices = sorted_indices[1:min(top_k, length(documents))]

    results = []
    for idx in top_indices
        push!(results, (
            document=documents[idx],
            similarity=similarities[idx],
            rank=findfirst(x -> x == idx, top_indices)
        ))
    end

    return results
end

"""
Find best matches above a similarity threshold.
"""
function find_best_matches(engine, query::String, documents::Vector{String}, threshold::Float64=0.7)
    similarities = batch_similarity(engine, query, documents)

    good_matches = []
    for (i, sim) in enumerate(similarities)
        if sim >= threshold
            push!(good_matches, (
                document=documents[i],
                similarity=sim,
                index=i
            ))
        end
    end

    # Sort by similarity
    sort!(good_matches, by=x -> x.similarity, rev=true)
    return good_matches
end

"""
Rank documents by relevance to query.
"""
function rank_documents(engine, query::String, documents::Vector{String})
    similarities = batch_similarity(engine, query, documents)
    rankings = sortperm(similarities, rev=true)

    return [(
        rank=i,
        document=documents[rankings[i]],
        similarity=similarities[rankings[i]]
    ) for i in 1:length(documents)]
end

"""
Search with similarity threshold filtering.
"""
function search_threshold(engine, query::String, documents::Vector{String}, min_similarity::Float64=0.5)
    results = semantic_search(engine, query, documents, top_k=length(documents))
    return filter(r -> r.similarity >= min_similarity, results)
end

"""
Fuzzy semantic search - finds documents similar to any of multiple query terms.
"""
function fuzzy_semantic_search(engine, queries::Vector{String}, documents::Vector{String}; top_k=5)
    all_similarities = []

    for query in queries
        sims = batch_similarity(engine, query, documents)
        push!(all_similarities, sims)
    end

    # Take maximum similarity across all queries for each document
    max_similarities = [maximum([sims[i] for sims in all_similarities]) for i in 1:length(documents)]

    sorted_indices = sortperm(max_similarities, rev=true)
    top_indices = sorted_indices[1:min(top_k, length(documents))]

    return [(
        document=documents[idx],
        similarity=max_similarities[idx],
        rank=i
    ) for (i, idx) in enumerate(top_indices)]
end

"""
Multi-query search: combine results from multiple related queries.
"""
function multi_query_search(engine, queries::Vector{String}, documents::Vector{String}; top_k=5, combine_method=:average)
    all_similarities = []

    for query in queries
        sims = batch_similarity(engine, query, documents)
        push!(all_similarities, sims)
    end

    # Combine similarities
    combined_similarities = if combine_method == :average
        [mean([sims[i] for sims in all_similarities]) for i in 1:length(documents)]
    elseif combine_method == :max
        [maximum([sims[i] for sims in all_similarities]) for i in 1:length(documents)]
    else
        error("Unknown combine_method: $combine_method")
    end

    sorted_indices = sortperm(combined_similarities, rev=true)
    top_indices = sorted_indices[1:min(top_k, length(documents))]

    return [(
        document=documents[idx],
        similarity=combined_similarities[idx],
        rank=i
    ) for (i, idx) in enumerate(top_indices)]
end

"""
Simple sentiment classification using example texts.
"""
function classify_sentiment(engine, text::String;
    positive_examples=["I love this", "Great job", "Fantastic", "Amazing work", "Excellent"],
    negative_examples=["I hate this", "Terrible", "Awful", "Bad work", "Horrible"])

    pos_similarities = batch_similarity(engine, text, positive_examples)
    neg_similarities = batch_similarity(engine, text, negative_examples)

    avg_pos = mean(pos_similarities)
    avg_neg = mean(neg_similarities)

    sentiment = avg_pos > avg_neg ? "positive" : "negative"
    confidence = abs(avg_pos - avg_neg)

    return (
        sentiment=sentiment,
        confidence=confidence,
        positive_score=avg_pos,
        negative_score=avg_neg
    )
end

"""
Classify text based on example categories.
"""
function classify_by_examples(engine, text::String, categories::Dict{String,Vector{String}})
    category_scores = Dict{String,Float64}()

    for (category, examples) in categories
        similarities = batch_similarity(engine, text, examples)
        category_scores[category] = mean(similarities)
    end

    best_category = argmax(category_scores)
    confidence = category_scores[best_category]

    return (
        category=best_category,
        confidence=confidence,
        all_scores=category_scores
    )
end

"""
Nearest neighbor classification.
"""
function nearest_neighbor_classify(engine, text::String, labeled_examples::Vector{Tuple{String,String}})
    max_similarity = -1.0
    predicted_label = ""

    for (example_text, label) in labeled_examples
        sim = text_similarity(engine, text, example_text)
        if sim > max_similarity
            max_similarity = sim
            predicted_label = label
        end
    end

    return (label=predicted_label, confidence=max_similarity)
end

"""
Cluster texts into similar groups.
"""
function cluster_texts(engine, texts::Vector{String}; similarity_threshold=0.7)
    clusters = []
    assigned = Set{Int}()

    for i in 1:length(texts)
        if i in assigned
            continue
        end

        cluster = [i]
        push!(assigned, i)

        for j in (i+1):length(texts)
            if j in assigned
                continue
            end

            sim = text_similarity(engine, texts[i], texts[j])
            if sim >= similarity_threshold
                push!(cluster, j)
                push!(assigned, j)
            end
        end

        push!(clusters, cluster)
    end

    return [(
        texts=[texts[idx] for idx in cluster],
        indices=cluster,
        size=length(cluster)
    ) for cluster in clusters]
end

"""
Find outlier texts that don't fit with the group.
"""
function find_outliers(engine, texts::Vector{String}; threshold=0.3)
    outliers = []

    for i in 1:length(texts)
        similarities_to_others = []

        for j in 1:length(texts)
            if i != j
                sim = text_similarity(engine, texts[i], texts[j])
                push!(similarities_to_others, sim)
            end
        end

        avg_similarity = mean(similarities_to_others)

        if avg_similarity < threshold
            push!(outliers, (
                text=texts[i],
                index=i,
                avg_similarity=avg_similarity
            ))
        end
    end

    return outliers
end

"""
Group texts by similarity.
"""
function group_similar_texts(engine, texts::Vector{String}; min_group_size=2, similarity_threshold=0.6)
    similarity_matrix = create_similarity_matrix(engine, texts)
    groups = []
    used_indices = Set{Int}()

    for i in 1:length(texts)
        if i in used_indices
            continue
        end

        group = [i]

        for j in (i+1):length(texts)
            if j in used_indices
                continue
            end

            if similarity_matrix[i, j] >= similarity_threshold
                push!(group, j)
            end
        end

        if length(group) >= min_group_size
            for idx in group
                push!(used_indices, idx)
            end
            push!(groups, (
                texts=[texts[idx] for idx in group],
                indices=group,
                avg_similarity=mean([similarity_matrix[group[i], group[j]]
                                     for i in 1:length(group) for j in (i+1):length(group)])
            ))
        end
    end

    return groups
end

"""
Analyze text complexity based on embedding patterns.
"""
function analyze_text_complexity(engine, text::String; reference_simple="The cat sat on the mat",
    reference_complex="The implementation of quantum computational algorithms necessitates sophisticated error correction protocols")

    simple_sim = text_similarity(engine, text, reference_simple)
    complex_sim = text_similarity(engine, text, reference_complex)

    complexity_score = complex_sim / (simple_sim + complex_sim)

    return (
        complexity_score=complexity_score,
        simple_similarity=simple_sim,
        complex_similarity=complex_sim,
        assessment=complexity_score > 0.6 ? "complex" : complexity_score > 0.4 ? "moderate" : "simple"
    )
end

"""
Compare writing styles between texts.
"""
function compare_writing_styles(engine, text1::String, text2::String)
    # Compare with different style examples
    formal_examples = ["The research demonstrates significant findings", "We hereby conclude the analysis"]
    informal_examples = ["This is pretty cool stuff", "Yeah, so anyway..."]
    technical_examples = ["Algorithm optimization requires computational complexity analysis", "The neural network architecture"]

    text1_formal = mean(batch_similarity(engine, text1, formal_examples))
    text1_informal = mean(batch_similarity(engine, text1, informal_examples))
    text1_technical = mean(batch_similarity(engine, text1, technical_examples))

    text2_formal = mean(batch_similarity(engine, text2, formal_examples))
    text2_informal = mean(batch_similarity(engine, text2, informal_examples))
    text2_technical = mean(batch_similarity(engine, text2, technical_examples))

    style_similarity = text_similarity(engine, text1, text2)

    return (
        style_similarity=style_similarity,
        text1_style=(formal=text1_formal, informal=text1_informal, technical=text1_technical),
        text2_style=(formal=text2_formal, informal=text2_informal, technical=text2_technical),
        style_match=style_similarity > 0.7 ? "similar" : "different"
    )
end

"""
Detect topics in text using similarity to topic keywords.
"""
function detect_topics(engine, text::String; topics=Dict(
    "technology" => ["computer", "software", "programming", "digital", "internet"],
    "science" => ["research", "experiment", "hypothesis", "data", "analysis"],
    "business" => ["market", "profit", "strategy", "customer", "revenue"],
    "health" => ["medical", "treatment", "patient", "diagnosis", "therapy"]
))

    topic_scores = Dict{String,Float64}()

    for (topic, keywords) in topics
        keyword_similarities = batch_similarity(engine, text, keywords)
        topic_scores[topic] = mean(keyword_similarities)
    end

    best_topic = argmax(topic_scores)
    confidence = topic_scores[best_topic]

    return (
        primary_topic=best_topic,
        confidence=confidence,
        all_topics=topic_scores
    )
end

"""
Measure coherence of a text by comparing sentences.
"""
function measure_coherence(engine, text::String)
    sentences = split(text, r"[.!?]+")
    sentences = [strip(s) for s in sentences if length(strip(s)) > 0]

    if length(sentences) < 2
        return (coherence_score=1.0, sentence_count=length(sentences))
    end

    coherence_scores = []
    for i in 1:(length(sentences)-1)
        sim = text_similarity(engine, sentences[i], sentences[i+1])
        push!(coherence_scores, sim)
    end

    avg_coherence = mean(coherence_scores)

    return (
        coherence_score=avg_coherence,
        sentence_count=length(sentences),
        assessment=avg_coherence > 0.6 ? "coherent" : avg_coherence > 0.4 ? "moderate" : "fragmented"
    )
end

"""
Find key phrases by comparing with the full text.
"""
function find_key_phrases(engine, text::String; min_length=10)
    sentences = split(text, r"[.!?]+")
    sentences = [strip(s) for s in sentences if length(strip(s)) >= min_length]

    if length(sentences) < 2
        return []
    end

    phrase_scores = []
    for sentence in sentences
        sim = text_similarity(engine, sentence, text)
        push!(phrase_scores, (phrase=sentence, relevance=sim))
    end

    sort!(phrase_scores, by=x -> x.relevance, rev=true)
    return phrase_scores
end

"""
Analyze readability based on similarity to simple/complex examples.
"""
function analyze_readability(engine, text::String)
    simple_examples = ["The dog ran fast", "I like ice cream", "The sun is bright"]
    complex_examples = ["The multifaceted approach", "Comprehensive analysis reveals", "Subsequently, we observed"]

    simple_scores = batch_similarity(engine, text, simple_examples)
    complex_scores = batch_similarity(engine, text, complex_examples)

    readability_score = mean(simple_scores) / (mean(simple_scores) + mean(complex_scores))

    return (
        readability_score=readability_score,
        assessment=readability_score > 0.6 ? "easy" : readability_score > 0.4 ? "moderate" : "difficult",
        simple_similarity=mean(simple_scores),
        complex_similarity=mean(complex_scores)
    )
end

"""
Create a text database with precomputed embeddings.
"""
function create_text_database(engine, texts::Vector{String})
    embeddings = [get_embeddings(engine, text) for text in texts]

    return (
        texts=texts,
        embeddings=embeddings,
        size=length(texts)
    )
end

"""
Process multiple texts efficiently.
"""
function batch_process_texts(engine, texts::Vector{String}, operation::Symbol=:embeddings)
    results = []

    for (i, text) in enumerate(texts)
        if operation == :embeddings
            result = get_embeddings(engine, text)
        elseif operation == :tokens
            result = encode_text(engine, text)
        elseif operation == :analysis
            result = analyze_context(engine, text)
        else
            error("Unknown operation: $operation")
        end

        push!(results, (
            index=i,
            text=text,
            result=result
        ))
    end

    return results
end

"""
Create similarity matrix for a set of texts.
"""
function create_similarity_matrix(engine, texts::Vector{String})
    n = length(texts)
    similarity_matrix = zeros(Float64, n, n)

    for i in 1:n
        similarity_matrix[i, i] = 1.0  # Self-similarity
        for j in (i+1):n
            sim = text_similarity(engine, texts[i], texts[j])
            similarity_matrix[i, j] = sim
            similarity_matrix[j, i] = sim  # Symmetric
        end
    end

    return similarity_matrix
end

"""
Convert text to embedding vector.
"""
text_to_vector(engine, text::String) = get_embeddings(engine, text)

"""
Normalize embeddings to unit length.
"""
function normalize_embeddings(embeddings::Vector{Float64})
    return embeddings / norm(embeddings)
end

"""
Simple dimensionality reduction using PCA (conceptual - would need actual PCA implementation).
"""
function reduce_dimensions(embeddings_matrix::Matrix{Float64}, target_dims::Int=50)
    # This is a placeholder - would need actual PCA implementation
    println("Note: This would require PCA implementation for actual dimensionality reduction")
    return embeddings_matrix[:, 1:min(target_dims, size(embeddings_matrix, 2))]
end

"""
Similarity matrix but more efficient for large datasets.
"""
function similarity_matrix(engine, texts::Vector{String})
    return create_similarity_matrix(engine, texts)
end

end # module
