#!/usr/bin/env ruby

require 'find'
require 'index_rdf'

require 'uuid'

NFO = RDF::Vocabulary.new('http://www.semanticdesktop.org/ontologies/2007/03/22/nfo#')
PC  = RDF::Vocabulary.new('http://purl.org/ontology/playcount/')

class MediaDB
  attr_reader :repo

  def initialize repo_path
    @repo = RDF::DataObjects::Repository.new repo_path
  end

  def new_file path
    puts "newfile #{path}"

    return unless path.match MEDIA_EXTENSIONS

    url = p2u(path)
    uri = RDF::URI.new(url)

    # we've already got this, whatevs
    unless @repo.query([uri, NFO.fileUrl, RDF::Literal.new(url)]).empty?
      return
    end

    # store the file's path
    st = RDF::Statement.new uri, NFO.fileUrl, RDF::Literal.new(url)
    @repo.insert(st)

    # store the file's mtime
    st = RDF::Statement.new uri, RDF::DC.date, RDF::Literal.new(File.mtime(path))
    @repo.insert(st)

    bnode = RDF::Node.uuid

    st = RDF::Statement.new uri, PC.playCount, bnode
    @repo.insert(st)

    st = RDF::Statement.new bnode, PC.count, RDF::Literal.new(0)
    @repo.insert(st)
  end

  def kill_file path
    file = p2f(path)
    puts "goodbye #{file}"
    @repo.delete([file, nil, nil])

    pc = _playcount(path)
    @repo.delete([pc, nil, nil])
  end

  def directory_deleted(path)
    puts " nodir #{path}"
    kill_file(path)
  end

  def directory_moved(old_path, new_path)
    puts "#{old_path} -> #{new_path}"

    # delete old triples
    kill_file(old_path)

    # add new ones
    Find.find(new_path) { |path| new_file(path) }
  end

  # increment a file's playcount
  def increment_playcount(path)
    # TODO: fix this
    return

    file = p2f(path)
    pc = self._playcount(file)
    return unless pc

    count = @repo.query([pc, PC.count, nil]).first.object.object.to_i
    count += 1

    @repo.delete([pc, PC.count, nil])
    @repo.insert([pc, PC.count, RDF::Literal.new(count)])
  end

  # get the bnode for a given file's playcount
  def _playcount(file)
    @repo.query([file, PC.playCount, nil]).first.object
  end

  def playcount(path)
    file = p2f(path)
    return 0 unless file
    pc = self._playcount(file)
    return 0 unless pc
    @repo.query([pc, PC.count, nil]).first.object.object.to_i
  end

  # return urls that match the given query
  def search q
    @repo.query_search(nil, NFO::fileUrl, q).map { |st| st.object.object }
  end

  # convert a path to a file URL
  def p2u path
    'file://' + path
  end

  # convert a path to the File's URI
  def p2f path
    st = @repo.query([nil, NFO.fileUrl, p2u(path)]).first
    st and st.subject
  end
end

if __FILE__ == $0
  require 'config'
  require 'index_rdf'

  db = MediaDB.new(REPO_PATH)

  Find.find(MEDIA_ROOT) do |path|
    db.new_file(path) unless EXCLUDE.member? path
  end
end
