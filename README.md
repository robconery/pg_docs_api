# A Simple Document API For PostgreSQL

This project sprang from some explorations I did while trying to figure out whether PostgreSQL would be a viable document database. In short: *yes, it is* but the API could use a little love. And since this is PostgreSQL and I like writing functions, I put together a simple API for working with documents in `jsonb`.

## Requirements

These functions use PLV8 (Google's V8 JS engine bolted on to PostgreSQL) for clarity. I wanted to "think in Javascript" when doing this (not sure why, it hurts).

So, be sure your install has PLV8.

## Installation

Just run the `api.sql` file and you're good to go. I split things out into their own files for clarity and since everything is pretty small I just put it all together by hand. I spose I could create make file ...

Anyway:

```
psql your_db < api.sql
```

## Usage

These functions are pretty utilitarian in nature - they are here to serve you and abstract a few duties. They are NOT here to serve as any kind of ORM.

To save a document, you use:

```sql
select * from save_document('monkies', '{"name" : "foofer"}');
```

This will do a few things:

 - Create the table `foofer` with a primary key, `tsvector` search column and timestamps
 - Insert the JSON in the body field as `jsonb`
 - Create an index on the body field using GIN with `jsonb_path_ops`
 - Create an index on the `tsvector` field using GIN as well

What you'll get back from this query is some `jsonb`:

```js
{"id" : 1, "name" : "foofer"}
```

Note here that the ID was added to the saved bit of JSON. The save routine makes sure the id is always synchronized with the row primary key. This makes things much more efficient which you'll see in the next section. If you include an id in the save routine the insert will not go off, instead it will try to update.

If you peer at the table you'll see the timestamps were set for you and that there are some tokens in the `tsvector` field that we also populated for you. More on that below.

## Finding Things

You can find a document in two ways, by `id` (primary key lookup) or by a `contains` match. Because the `id` is synchronized with the document, the ID lookup is as fast as a primary key lookup:

```sql
select * from find_document('monkies', 1);
{"id" : 1, "name" : "foofer"}
```

You can also match on criteria (sending in an order by field as well):

```sql
select * from find_document('monkies', '{"name" : "foofer"}', 'id');
{"id" : 1, "name" : "foofer"}
```

In this latter query a `contains` operator is being used under the hood:

```sql
select body from monkies where
body @ '{"name" : "foofer"}'
order by id;
```

This is important because this query will use the GIN index that was created for you and is an optimized query.

The find queries return a single result - you can return more than one using filter:

```sql
select * from filter_documents('monkies', '{"name" : "foofer"}');
{"id" : 1, "name" : "foofer"}
```

## Full Text Queries

If you have a look at the `update_search` function you'll see that the keys from a given document are searched for "typical" indexable columns (name, first, last, email, city etc). You can change this as you like. If one of these columns is found, its value will be added to the search index.

We can now search for our monkey by name:

```sql
select * from search_documents('monkies', 'foofer');
{"id" : 1, "name" : "foofer"}
```

This search is highly optimized and very, very fast.

## PLPGSQL

I chose PLV8 because it's a little bit more elegant and concise when compared to PLPGSQL, however I understand that installing PLV8 might not be an option for some.

If you'd like to convert this, please do. I'd be happy to add an optional PLPGSQL install.
