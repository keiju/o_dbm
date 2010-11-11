#!/usr/local/bin/ruby
#
#   test-odbm.rb - 
#   	$Release Version: 0.5.1$
#   	$Revision: 1.1 $
#   	$Date: 1997/08/08 00:57:08 $
#   	by Keiju ISHITSUKA(Nippon Rational Inc.)
#
# --
#
#   
#

RCS_ID='-$Header: /home/keiju/var/src/var.lib/header/RCS/ruby-mode,v 1.1 1997/08/08 00:57:08 keiju Exp keiju $-'

$:.unshift ENV["HOME"]+"/var/lib/ruby"
$:.unshift "."

require "./o_dbm"

class Foo
  def initialize
    @foo = 1
    @bar = 2
  end
end

adapter = ObjectDBM::DBM_Adapter
if ARGV.include?("DBM")
  adapter = ObjectDBM::DBM_Adapter
elsif ARGV.include?("SDBM")
  adapter = ObjectDBM::SDBM_Adapter
elsif ARGV.include?("GDBM")
  adapter = ObjectDBM::GDBM_Adapter
elsif ARGV.include?("PHash")
  adapter = ObjectDBM::PHash_Adapter
elsif ARGV.include?("VDB")
  adapter = ObjectDBM::VDB_Adapter
end

odbm = ObjectDBM.new("test.db", adapter)

def dump(odbm)
  odbm.transaction do
    for k, v in odbm
      print k, "=>"
      p v
    end
  end
end

case ARGV[0]
when "-s"

  print "TEST: 0\n"
  odbm.transaction do
    p odbm["1"]
  end

  print "TEST: 1\n"
  odbm.transaction do
    odbm["1"] = Foo.new
    p odbm["1"]
    p odbm
  end

  print "TEST: 2\n"
  odbm.transaction do
    p odbm["1"]
  end

  print "TEST: 3\n"
  odbm.transaction do
    for k, v in odbm
      print k, "=>"
      p v
    end
  end

  print "TEST: 4\n"
  odbm.transaction do
    odbm["2"] = "1"
    odbm.transaction do
      odbm["3"] = "2"
    end
  end

  dump(odbm)
  
  print "TEST: 5\n"
  odbm.transaction do
    |tx|
    odbm["4"] = "1"
    tx.abort
  end

  dump(odbm)

  print "TEST: 6\n"
  odbm.transaction do
    odbm["5"] = "1"
    odbm.transaction do
      |tx|
      odbm["4"] = "1"
      tx.abort
    end
    odbm["6"] = "2"
  end

  dump(odbm)
  
  print "TEST: 7\n"
  odbm.transaction do
    |tx|
    odbm["7"] = 7
    odbm.transaction do
      odbm["8"] = 8
    end
    tx.abort
    odbm["9"] = 9
  end

  dump(odbm)

  print "TEST: 8\n"
  odbm.transaction do
    |tx|
    odbm["8-1"] = 81
    catch :FOO do
      odbm.transaction do
	odbm["8-2"] = 82
	throw :FOO
      end
    end
    odbm["8-3"] = 83
  end

  dump(odbm)
  
  print "TEST: 9\n"
  odbm.transaction do
    |tx|
    odbm["9-1"] = 91
    begin
      odbm.transaction do
	odbm["9-2"] = 92
	fail "foo"
      end
    rescue
    end
    odbm["9-3"] = 93
  end

  dump(odbm)

when "-d"

  print "TEST: 0\n"
  txn = odbm.transaction
    p odbm["1"]
  txn.commit


  print "TEST: 1\n"
  txn = odbm.transaction
  odbm["1"] = Foo.new
  p odbm["1"]
  p odbm
  txn.commit

  dump(odbm)

  print "TEST: 2\n"
  txn = odbm.transaction
  p odbm["1"]
  txn.commit

  print "TEST: 3\n"
  txn =  odbm.transaction
  for k, v in odbm
    print k, "=>"
    p v
  end
  txn.commit

  print "TEST: 4\n"
  txn1 = odbm.transaction
  odbm["2"] = "1"
  txn2 = odbm.transaction
  odbm["3"] = "2"
  txn2.commit
  txn1.commit

  dump(odbm)
  
  print "TEST: 5\n"
  txn1 = odbm.transaction
  odbm["4"] = "1"
  txn1.abort

  dump(odbm)

  print "TEST: 6\n"
  txn1 = odbm.transaction
  odbm["5"] = "1"
  txn2 = odbm.transaction
  odbm["4"] = "1"
  txn2.abort
  odbm["6"] = "2"
  txn1.commit

  dump(odbm)

  print "TEST: 7\n"
  txn1 = odbm.transaction
  odbm["7"] = 7
  txn2 = odbm.transaction
  odbm["8"] = 8
  txn2.commit
  odbm["9"] = 9
  p odbm["8"]
  txn1.abort

  dump(odbm)

  print "TEST: 8\n"
  tx1 = odbm.transaction
  odbm["8-1"] = 81
  catch :FOO do
    tx2 = odbm.transaction
    odbm["8-2"] = 82
    throw :FOO
    tx2.commit
  end
  odbm["8-3"] = 83
  tx1.commit

  dump(odbm)
  
  print "TEST: 9\n"
  txn1 = odbm.transaction
  odbm["9-1"] = 91
  begin
    txn2 = odbm.transaction
    odbm["9-2"] = 92
    fail "foo"
    txn2.commit
  rescue
  end
  odbm["9-3"] = 93
  txn1.commit

  dump(odbm)

when "-e1"

  odbm.transaction do
    tx = odbm.transaction
    tx.commit
  end

when "-e2"

  odbm.transaction do
    tx = odbm.transaction
    tx.commit
  end
else
  print "no nothing!\n"
end

