require 'rubygems'
require 'rdf'

require 'rdf/do'
require 'do_sqlite3'

# woop woop monkeypatching
require 'rdf/do/adapters/sqlite3'
module RDF::DataObjects::Adapters::Defaults
  def query_search(repository, hash = {})
    conditions = []
    params = []

    [:subject, :predicate, :object, :context].each do |resource|
      next if hash[resource].nil?

      if hash[resource].is_a? RDF::URI
        # do a resource match
        conditions << "#{resource.to_s} = ?"
        params     << repository.serialize(hash[resource])
      else
        conditions << "#{resource.to_s} MATCH ?"
        params     << hash[resource].to_s
      end
    end

    where = conditions.empty? ? '' : 'WHERE '
    where << conditions.join(' AND ')

    repository.result('SELECT * FROM quads ' + where, *params)
  end

  def query_prefix(repository, hash = {})
    conditions = []
    params = []

    [:subject, :predicate, :object, :context].each do |resource|
      next if hash[resource].nil?

      if hash[resource].is_a? RDF::URI
        # do a resource match
        conditions << "#{resource.to_s} = ?"
        params     << repository.serialize(hash[resource])
      else
        # do a prefix match
        conditions << "#{resource.to_s} LIKE ?"
        params     << '"' + hash[resource].to_s + '%'
      end
    end

    where = conditions.empty? ? '' : 'WHERE '
    where << conditions.join(' AND ')

    repository.result('SELECT * FROM quads ' + where, *params)
  end
end

class RDF::DataObjects::Repository
  # hahahaahahaha soooo inconsistent with what has gone before
  def query_search *pattern, &block
    pattern = {
      :subject   => pattern[0],
      :predicate => pattern[1],
      :object    => pattern[2]
    }

    statements = []
    reader = @adapter.query_search(self, pattern)

    while reader.next!
      st = RDF::Statement.new(
              :subject   => unserialize(reader.values[0]),
              :predicate => unserialize(reader.values[1]),
              :object    => unserialize(reader.values[2]),
              :context   => unserialize(reader.values[3]))

      if block_given?
        yield st
      else
        statements << st
      end
    end

    statements unless block_given?
  end

  def query_prefix *pattern, &block
    pattern = {
      :subject   => pattern[0],
      :predicate => pattern[1],
      :object    => pattern[2]
    }

    statements = []
    reader = @adapter.query_prefix(self, pattern)

    while reader.next!
      st = RDF::Statement.new(
              :subject   => unserialize(reader.values[0]),
              :predicate => unserialize(reader.values[1]),
              :object    => unserialize(reader.values[2]),
              :context   => unserialize(reader.values[3]))

      if block_given?
        yield st
      else
        statements << st
      end
    end

    statements unless block_given?
  end
end

# enable full text search
class RDF::DataObjects::Adapters::Sqlite3
  def self.migrate?(do_repository, opts = {})
    begin
      # test if the table exists in a dumb halfassed way
      do_repository.exec('SELECT 1 FROM quads WHERE 1 = 0')
    rescue
      # here I foolishly assume that the exception was "no such table"
      do_repository.exec('CREATE VIRTUAL TABLE quads USING fts3 (`subject` varchar(255), `predicate` varchar(255), `object` varchar(255), `context` varchar(255), UNIQUE (`subject`, `predicate`, `object`, `context`))')
    end
    begin do_repository.exec('CREATE INDEX `quads_context_index` ON `quads` (`context`)') rescue nil end
    begin do_repository.exec('CREATE INDEX `quads_object_index` ON `quads` (`object`)') rescue nil   end
    begin do_repository.exec('CREATE INDEX `quads_predicate_index` ON `quads` (`predicate`)') rescue nil end
    begin do_repository.exec('CREATE INDEX `quads_subject_index` ON `quads` (`subject`)') rescue nil end
  end
end
