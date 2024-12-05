/* 
Project Title: IMDB Top 1000 Movies Data Analysis
Data source: https://www.kaggle.com/datasets/harshitshankhdhar/imdb-dataset-of-top-1000-movies-and-tv-shows?select=imdb_top_1000.csv
Queried using: MySQL
Some pre-cleaning has been done by Excel in order to import to MySQL properly, including removing the Poster_Link column and replacing commas with fullstops at the Overview column.
*/

-- 1. Data Overview

USE imdb_movies;
SELECT 
    *
FROM
    movies
LIMIT 10;

-- 2. Data Preparation and Cleaning

-- Update Blank Values to NULL for Numeric Columns
UPDATE movies 
SET 
    Certificate = NULL
WHERE
    TRIM(IMDB_Rating) = '';

UPDATE movies 
SET 
    Meta_score = NULL
WHERE
    TRIM(Meta_score) = '';

UPDATE movies 
SET 
    Gross = NULL
WHERE
    TRIM(Gross) = '';

-- Update Datatypes
ALTER TABLE movies 
    MODIFY Series_Title VARCHAR(255),
    MODIFY Released_Year VARCHAR(4), 
    MODIFY Certificate VARCHAR(20),
    MODIFY Runtime VARCHAR(20),
    MODIFY Genre VARCHAR(255),
    MODIFY IMDB_Rating FLOAT,
    MODIFY Overview TEXT,
    MODIFY Meta_score FLOAT,
    MODIFY Director VARCHAR(255),
    MODIFY Star1 VARCHAR(255),
    MODIFY Star2 VARCHAR(255),
    MODIFY Star3 VARCHAR(255),
    MODIFY Star4 VARCHAR(255),
    MODIFY No_of_Votes INT,
    MODIFY Gross FLOAT;
    
-- Look Up the Row Where Released_Year is Not a Number
SELECT 
    Series_Title, Released_Year
FROM
    movies
WHERE
    NOT Released_Year REGEXP '^[0-9]{4}$';
-- Expected Result:
-- Series_Title: Apollo 13, Released_Year: "PG"

-- Correct Released Year of Apollo 13 to 1995
UPDATE movies 
SET 
    Released_Year = '1995'
WHERE
    Series_Title = 'Apollo 13'
        AND NOT Released_Year REGEXP '^[0-9]{4}$';

-- 3. Analysis Queries

-- 3.1 What Are the Oldest and Newest Movies in the Dataset?
SELECT 
    *
FROM
    movies
WHERE
    Released_Year = (SELECT 
            MIN(Released_Year)
        FROM
            movies)
LIMIT 1;
SELECT 
    *
FROM
    movies
WHERE
    Released_Year = (SELECT 
            MAX(Released_Year)
        FROM
            movies)
LIMIT 1;
-- The Dataset Consists of Movies Released Between 1920-2020.

-- 3.2 What is the Movie with the Highest Rating?
SELECT 
    *
FROM
    movies
WHERE
    IMDB_Rating = (SELECT 
            MAX(IMDB_Rating)
        FROM
            movies)
ORDER BY Released_Year;
-- The Highest Rating is 9.3 with only 1 Movie - The Shawshank Redemption Released in 1994

-- 3.3 What is the Movie with the Lowest Rating?
SELECT 
    *
FROM
    movies
WHERE
    IMDB_Rating = (SELECT 
            MIN(IMDB_Rating)
        FROM
            movies)
ORDER BY Released_Year;
-- The Lowest Rating is 7.6 with 123 Movies

-- 3.4 What are the Top 10 Movies with the Highest Gross Revenue?
SELECT 
    *
FROM
    movies
ORDER BY Gross DESC
LIMIT 10;
-- The Most Profitable Movie in this Dataset is Star Wars VII Released in 2015 Grossed $936.66 Million

-- 3.5 What are the Highest-Rated Movies by Decade?
WITH MoviesByDecade AS (
    SELECT Series_Title, Released_Year, Director, Genre, 
           CONCAT(SUBSTRING(CAST((Released_Year DIV 10) * 10 AS CHAR), 3, 2), 's') AS Decade,
           IMDB_Rating
    FROM movies
    WHERE Released_Year REGEXP '^[0-9]{4}$'
)
SELECT Decade, Series_Title, Director, Genre, Released_Year, IMDB_Rating
FROM (
    SELECT Series_Title, Released_Year, Director, Genre, Decade, IMDB_Rating,
           RANK() OVER (PARTITION BY Decade ORDER BY IMDB_Rating DESC) AS Ranked
    FROM MoviesByDecade
) AS RankedMovies
WHERE Ranked = 1;
-- 12 Rows Returned with 2 Movies of the Same Rating in 20s and 30s Respectively

-- 3.6 Who are the Top 10 Most Popular (Counted by No. of Votes) Directors?
SELECT 
    Director,
    SUM(No_of_Votes) AS Total_votes,
    COUNT(Series_Title) AS No_of_movies
FROM
    movies
GROUP BY Director
ORDER BY Total_votes DESC
LIMIT 10;
-- The Most Popular Director is Christopher Nolan

-- 3.7 Which Top 10 Directors have the Most Movies in the Dataset?
SELECT 
    Director,
    SUM(No_of_Votes) AS Total_votes,
    COUNT(Series_Title) AS No_of_movies
FROM
    movies
GROUP BY Director
ORDER BY No_of_movies DESC
LIMIT 10;
-- Alfred Hitchcock had 14 Movies at the Top of the List

-- 3.8 Which Directos Also Starred in their Movies?
SELECT 
    Director,
    Series_Title,
    Released_Year,
    IMDB_Rating,
    CASE
        WHEN Director = Star1 THEN 'Star1'
        WHEN Director = Star2 THEN 'Star2'
        WHEN Director = Star3 THEN 'Star3'
        WHEN Director = Star4 THEN 'Star4'
    END AS Actor_Role
FROM
    movies
WHERE
    Director IN (Star1 , Star2, Star3, Star4)
ORDER BY Released_Year DESC;
-- 12 Movies Returned, with Directors Like Charles Chaplin, Clint Eastwood and Woody Allen

-- 3.9 What are the Most Profitable Genres?
WITH split_genre AS (
SELECT 
    Series_Title, 
    Released_Year, 
    Director, 
    IMDB_Rating, 
    Gross, 
    Genre, 
    -- First Genre: always extract the first genre
    TRIM(SUBSTRING_INDEX(Genre, ',', 1)) AS First_Genre,
    
    -- Second Genre: only extract if there is more than one genre (i.e., there is a comma)
    CASE
        WHEN Genre LIKE '%,%' THEN TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(Genre, ',', 2), ',', -1))
        ELSE NULL
    END AS Second_Genre,
    
    -- Third Genre: only extract if there are at least two commas (i.e., more than two genres)
    CASE
        WHEN Genre LIKE '%,%,%' THEN TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(Genre, ',', 3), ',', -1))
        ELSE NULL
    END AS Third_Genre
FROM 
    movies)
SELECT Genre, 
       SUM(Gross) AS Total_Gross
FROM (
    -- Union all genres into a single column for easier grouping
    SELECT First_Genre AS Genre, Gross FROM split_genre WHERE First_Genre IS NOT NULL
    UNION ALL
    SELECT Second_Genre AS Genre, Gross FROM split_genre WHERE Second_Genre IS NOT NULL
    UNION ALL
    SELECT Third_Genre AS Genre, Gross FROM split_genre WHERE Third_Genre IS NOT NULL
) AS AllGenres
GROUP BY Genre
ORDER BY Total_Gross DESC;
-- The Most Profitable Genre is Adventure, followed by Drama and Action

-- 3.10 Who are the Top 3 Most Appeared Actors/Actress in the dataset?
SELECT Star_Name, COUNT(*) AS Appearance_Count
FROM (
    SELECT Star1 AS Star_Name FROM movies
    UNION ALL
    SELECT Star2 AS Star_Name FROM movies
    UNION ALL
    SELECT Star3 AS Star_Name FROM movies
    UNION ALL
    SELECT Star4 AS Star_Name FROM movies
) AS All_Stars
GROUP BY Star_Name
ORDER BY Appearance_Count DESC
LIMIT 3;
-- Robert De Niro appeared most with 17 times, followed by Tom Hanks 14 times and Al Pacino 13 times

-- 3.11 What are the Freqencies of Certain Keywords Appeared in the Dataset?
SELECT 
    SUM(LOWER(Overview) LIKE '%love%') AS Love,
    SUM(LOWER(Overview) LIKE '%family%') AS Family,
    SUM(LOWER(Overview) LIKE '%enlighten%') AS Enlighten,
    SUM(LOWER(Overview) LIKE '%london%') AS London,
    SUM(LOWER(Overview) LIKE '%revenge%') AS Revenge,
    SUM(LOWER(Overview) LIKE '%henry%') AS Henry,
    SUM(LOWER(Overview) LIKE '%regret%') AS Regret
FROM
    movies;
-- Word Count {Love: 83, Family: 63, Enlighten: 1, London: 7, Revenge: 7, Henry: 5, Regret: 2}