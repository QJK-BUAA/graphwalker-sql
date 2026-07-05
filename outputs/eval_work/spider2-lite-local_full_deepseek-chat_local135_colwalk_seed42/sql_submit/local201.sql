-- We need to find words that have at least one anagram of the same length.
-- An anagram is a word formed by rearranging the letters of another word.
-- Since we consider case-sensitive letters, we treat uppercase and lowercase as distinct.
-- We have a single table word_list with column words.
-- First, filter words that are 4 or 5 characters long, start with 'r' (case-sensitive, so 'r' not 'R').
-- Then, for each such word, find other words of the same length that are anagrams.
-- An anagram can be identified by sorting the characters of the word.
-- Since SQLite does not have a built-in sort function for strings, we need to create a custom function or use a recursive CTE.
-- However, we can use a trick: for each word, we can generate a signature by sorting its characters.
-- We'll use a recursive CTE to split each word into characters, sort them, and concatenate back.
-- Then join on the signature to find anagrams.
-- Finally, count the number of anagrams (excluding the word itself) for each word, and select the first 10 alphabetically.

WITH RECURSIVE
-- Generate numbers up to the maximum word length (5)
numbers(n) AS (
    SELECT 1
    UNION ALL
    SELECT n+1 FROM numbers WHERE n < 5
),
-- Split each word into characters with positions
split_words AS (
    SELECT w.words,
           substr(w.words, n.n, 1) AS ch,
           n.n AS pos
    FROM word_list w
    JOIN numbers n ON n.n <= length(w.words)
    WHERE length(w.words) IN (4, 5)
      AND w.words LIKE 'r%'
),
-- Sort characters alphabetically (case-sensitive, so we use ASCII order)
sorted_chars AS (
    SELECT words, ch,
           row_number() OVER (PARTITION BY words ORDER BY ch) AS rn
    FROM split_words
),
-- Rebuild sorted string for each word
sorted_words AS (
    SELECT words,
           group_concat(ch, '') AS sorted_word
    FROM sorted_chars
    GROUP BY words
),
-- Find words that have at least one anagram (same sorted string, different word)
anagram_groups AS (
    SELECT sw.words,
           sw.sorted_word,
           COUNT(*) AS total_in_group
    FROM sorted_words sw
    GROUP BY sw.sorted_word
    HAVING COUNT(*) > 1
),
-- For each word in anagram groups, count the number of anagrams (excluding itself)
word_anagram_count AS (
    SELECT sw.words,
           (ag.total_in_group - 1) AS anagram_count
    FROM sorted_words sw
    JOIN anagram_groups ag ON sw.sorted_word = ag.sorted_word
)
-- Select the first 10 words alphabetically with their anagram count
SELECT wac.words, wac.anagram_count
FROM word_anagram_count wac
ORDER BY wac.words ASC
LIMIT 10