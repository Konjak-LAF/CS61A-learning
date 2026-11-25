CREATE TABLE parents (parent TEXT, child TEXT);

INSERT INTO parents VALUES
  ('ace', 'bella'),
  ('ace', 'charlie'),
  ('daisy', 'hank'),
  ('finn', 'ace'),
  ('finn', 'daisy'),
  ('finn', 'ginger'),
  ('ellie', 'finn');

CREATE TABLE dogs (name TEXT, fur TEXT, height INTEGER);

INSERT INTO dogs VALUES
  ('ace',     'long',  26),
  ('bella',   'short', 52),
  ('charlie', 'long',  47),
  ('daisy',   'long',  46),
  ('ellie',   'short', 35),
  ('finn',    'curly', 32),
  ('ginger',  'short', 28),
  ('hank',    'curly', 31);

CREATE TABLE sizes (size TEXT, min INTEGER, max INTEGER);

INSERT INTO sizes VALUES
  ('toy',      24, 28),
  ('mini',     28, 35),
  ('medium',   35, 45),
  ('standard', 45, 60);


-- All dogs with parents ordered by decreasing height of their parent
CREATE TABLE by_parent_height AS
  SELECT A.child
  from parents as A, dogs as B
  where A.parent == B.name
  order by -B.height;


-- The size of each dog
CREATE TABLE size_of_dogs AS
  SELECT A.name, B.size as name, size
  from dogs as A, sizes as B
  where B.min < A.height and A.height <= B.max
  ;


-- [Optional] Filling out this helper table is recommended
CREATE TABLE siblings AS
  SELECT A.child as first, B.child as second
  from parents as A, parents as B
  where A.parent == B.parent and A.child < B.child;

-- Sentences about siblings that are the same size
CREATE TABLE sentences AS
  SELECT "The two siblings, " || A.first || " and " || A.second || ", have the same size: " || B.size
  from siblings as A, size_of_dogs as B, size_of_dogs as C
  where A.first == B.name and A.second == C.name and B.size == C.size;


-- Height range for each fur type where all of the heights differ by no more than 30% from the average height
CREATE TABLE low_variance AS
  SELECT fur as fur, max(height) - min(height) as height_range
  from dogs
  group by fur
  HAVING 0.7 * AVG(height) <= min(height) and max(height) <= AVG(height) * 1.3;

