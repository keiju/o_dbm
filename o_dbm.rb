#
#   o_dbm.rb - オブジェクト指向データベース風Object Base DBM
#   	$Release Version: 0.5.1$
#   	$Revision: 1.9 $
#   	$Date: 2002/07/12 04:46:28 $
#   	by Keiju ISHITSUKA(Nippon Rational Inc.)
#
# --
#
#   
#

require "e2mmap"

class ObjectDBM
  @RELEASE_VERSION = "0.5.1"
  @LAST_UPDATE_DATE = "02/07/12"

  @RCS_ID='-$Id: o_dbm.rb,v 1.9 2002/07/12 04:46:28 keiju Exp keiju $-'

  extend Exception2MessageMapper

  # トップトランザクションでしか実行できないオペレーションを実行しよう
  # とした.  
  def_exception(:ErrOnlyUsableTopTransaction, 
		"The operation (%s) can only be executed in the top level transaction.")

  # トランザクション内でないと実行できないオペレーションを実行しようと
  # しました.
  def_exception(:ErrOnlyUsableInTransaction, 
		"The operation (%s) can only be executed within a transaction.")

  # 静的トランザクションと動的トランザクションを混在して利用することは
  # できません. 
  def_exception(:ErrMixedTransaction, 
		"Static transactions and dynamic transactions cannot be mixed together.")
  
  def_exception(:ErrAdapterInterfaceNotImplement,
		"Adapter interfase(%s) is not implemented.")

  include Enumerable

  ODBM = ObjectDBM

  STATIC_TRANSACTION_MODE = :ObjectDBM__STATIC_TRANSACTION_MODE
  DYNAMIC_TRANSACTION_MODE = :ObjectDBM__DYNAMIC_TRANSACTION_MODE

  NO_CACHING = :ObjectDBM__NO_CACHING
  READ_CACHING = :ObjectDBM__READ_CACHING
  UPDATE_CACHING = :ObjectDBM__UPDATE_CACHING

  CLEAR_READ_CACHE = :ObjectDBM__CLEAR_READ_CACHE
  HOLD_READ_CACHE = :ObjectDBM__HOLD_READ_CACHE

  SCAN_DB = :ObjectDBM__SCAN_DB
  SCAN_CACHE_ONLY = :ObjectDBM__SCAN_CACHE_ONLY
  SCAN_DB_ONLY = :ObjectDBM__SCAN_DB_ONLY

  READ = :ObjectDBM__READ
  UPDATE = :ObjectDBM__UPDATE
  ABORT = :ObjectDBM__ABORT

  NULL = :ODBM__NULL

  TRANSACTIONAL_OPERATIONS = [
    "[]", "update", "[]=", "delete", "indexes",
    "root_names", "keys", "roots", "values",
    "size", 
    "has_root_name?", "root_name?", "include?", "has_root?", "root?",
    "each", "each_pair", "each_root_name", "each_root", "each_value", 
    "commit", "abort"
  ]

  #----------------------------------------------------------------------
  #
  #  initialize and terminating  - 
  #	initialize
  #
  #----------------------------------------------------------------------
  def initialize(dbm_name, adapter = DBM_Adapter)
    @db_adapter = adapter

    @db_name = File.expand_path(dbm_name)
    @db = nil

    @default_value = nil

    @transaction_mode = nil
    @default_caching_mode = nil
    @read_cache = nil
    @write_cache = nil
    @delete_cache = nil

    @current_transaction = nil

    disable_transactional_methods
  end

  def disable_transactional_methods
    for op in TRANSACTIONAL_OPERATIONS
      instance_eval %[
	def #{op}(*opts)
	  error_not_transaction_start("#{op}")
	end
      ], __FILE__, __LINE__ - 5
    end
  end
  private :disable_transactional_methods

  def enable_transactional_methods
    for op in TRANSACTIONAL_OPERATIONS
      (class<<self; self; end).instance_eval{remove_method op}
    end
  end
  private :enable_transactional_methods

  def error_not_transaction_start(op)
    ODBM.Fail ErrOnlyUsableInTransaction, op
  end
  private :error_not_transaction_start

  #----------------------------------------------------------------------
  #
  #  accessing  - 
  #	[](key, mode)
  #	update(key, obj)
  #	[]=(key, obj)
  #	delete(key)
  #	indexes
  #	root_names
  #	keys
  #	roots
  #	values
  #	size
  #
  #----------------------------------------------------------------------
  attr_accessor :default_value
  alias default default_value
  alias default= default_value=

  def [](key, mode = nil)
    mode = @default_caching_mode unless mode

    return update(key) if mode == UPDATE
    obj = @read_cache[key]
    return obj unless obj == NULL
      
    return @default_value unless obj = @db[key]
    @read_cache[key] = obj if mode != NO_CACHING
    obj
  end

  def update(key, obj = :NO_OPTION)
    return self[key] = obj unless obj == :NO_OPTION

    return @write_cache[key] = obj unless (obj = @read_cache[key]) == NULL
    return @default_value unless obj = @db[key]
    @write_cache[key] = @read_cache[key] = obj

    @delete_cache.delete(key)
    obj
  end

  def []=(key, obj)
    @write_cache[key] = @read_cache[key] = obj
    @delete_cache.delete(key)
    obj
  end

  def delete(key)
    value = @write_cache.delete(key)
    value ||= @read_cache.delete(key)
    @delete_cache[key] = true
    value
  end

  def indexes(*keys)
    keys.collect{|key| self[key]}
  end
  alias indeces indexes

  def root_names
    keys = []
    each_key do
      |key|
      keys.push keys
    end
    keys
  end
  alias keys root_names

  def size
    no = 0
    each_key do
      |key|
      no += 1
    end
    no
  end

  def roots(mode = nil)
    values = []
    each_root(mode) do
      |root|
      values.push root
    end
    values
  end
  alias values roots

  #----------------------------------------------------------------------
  #
  #  testing  - 
  #	has_root_name?
  #	root_name?
  #	include?
  #	has_root?
  #	root?
  #
  #----------------------------------------------------------------------
  def has_root_name?(root_name, mode = SCAN_DB)
    return true if @read_cache.key?(root_name)
    return false if mode == SCAN_CACHE_ONLY
    @db.has_key?(root_name)
  end
  alias root_name? has_root_name?
  alias include? has_root_name?
  alias key? has_root_name?

  def has_root?(root, mode = SCAN_DB)
    return has_root(root, mode){|x,y| x.equal?(y)} if iterator?

    if mode != SCAN_DB_ONLY
      @read_cache.each_value{|r| return true if yield root, r}
      return false if mode == SCAN_CACHE_ONLY
    end
    @db.each_value{|r| return true if yield root, r}
    false
  end
  alias root? has_root?

  #----------------------------------------------------------------------
  #
  #  enumerating  - 
  #	each
  #	each_pair
  #	each_root_name
  #	each_key
  #	each_root
  #	each_value
  #
  #----------------------------------------------------------------------
  def each(mode = nil)
    mode = @default_caching_mode unless mode

    if mode != SCAN_DB_ONLY
      for key, value in @read_cache
	@write_cache[key] = value if mode == UPDATE
	yield key, value
      end
    end

    if mode != SCAN_CACHE_ONLY
      @db.each do |key, obj|
	next unless mode == SCAN_DB_ONLY or @read_cache[key] == NULL
	@read_cache[key] = obj if mode == READ_CACHING
	@write_cache[key] = obj if mode == UPDATE
	yield key, obj
      end
    end
  end
  alias each_pair each

  def each_root_name(mode = nil)
    mode = @default_caching_mode unless mode

    if mode != SCAN_DB_ONLY
      @read_cache.each_key do
	|key|
	yield key
      end
    end
      
    if mode != SCAN_CACHE_ONLY
      @db.each_key do
	|key|
	yield key if mode == SCAN_DB_ONLY or @read_cache[key] == NULL
      end
    end
  end
  alias each_key each_root_name

  def each_root(mode = nil)
    mode = @default_caching_mode unless mode

    each(mode) do
      |key, root|
      yield root
    end
  end
  alias each_value each_root

  #----------------------------------------------------------------------
  #
  #   transaction accessing - 
  #	transaction
  #     current_transaction
  #
  #----------------------------------------------------------------------
  def transaction(mode = READ_CACHING)
    @default_caching_mode = mode
    open(mode)

    outer = @current_transaction
    if outer
      # freeze old cache
      outer.read_cache = @read_cache.dup
      outer.write_cache = @write_cache.dup
      outer.delete_cache = @delete_cache.dup
    end

    if iterator?
      if @transaction_mode == DYNAMIC_TRANSACTION_MODE
	ODBM.Fail ErrMixedTransaction 
      end
      @transaction_mode = STATIC_TRANSACTION_MODE
      @current_transaction = StaticTransaction.new(self, mode, outer)
#      @current_transaction.transaction do
#	yield @current_transaction
#      end
      @current_transaction.transaction do |txn|
	yield txn
      end
    else
      if @transaction_mode == STATIC_TRANSACTION_MODE
	ODBM.Fail ErrMixedTransaction 
      end
      
      @transaction_mode = DYNAMIC_TRANSACTION_MODE

      @current_transaction = DynamicTransaction.new(self, mode, outer)
      @current_transaction.start
      return @current_transaction
    end

  end
  attr :current_transaction

  #----------------------------------------------------------------------
  #
  #  openning and closing  - system fuctions
  #
  #----------------------------------------------------------------------
  def commit(txn)
    @current_transaction = txn.outer
    if @current_transaction
      @mode = @current_transaction.mode
      @current_transaction.read_cache = @read_cache
      @current_transaction.write_cache = @write_cache
      @current_transaction.delete_cache = @delete_cache
    else
      close
    end
  end

  def flush(txn)
    if txn.outer
      txn.outer.read_cache = txn.read_cache.dup
      txn.outer.write_cache = txn.write_cache.dup
      txn.outer.delete_cache = txn.delete_cache.dup
    else
#      close(HOLD_READ_CACHE)
#      @db = @db_adapter.open(@db_name)
      flush_db
    end
  end
  

  def abort(txn)
    @current_transaction = txn.outer
    if @current_transaction
      @mode = @current_transaction.mode
      @read_cache = @current_transaction.read_cache
      @write_cache = @current_transaction.write_cache
      @delete_cache = @current_transaction.delete_cache
    else
      close_with_no_flush
    end
  end
  public :abort

  def open(mode = READ_CACHING)
    if !@db
      @db = @db_adapter.open(@db_name)
      enable_transactional_methods
    end
    unless @read_cache
      @read_cache = {} 
      @read_cache.default = NULL
    end
    unless @write_cache
      @write_cache = {}
      @write_cache.default = NULL
    end
    unless @delete_cache
      @delete_cache = {}
      @delete_cache.default = NULL
    end

    self
  end
  private :open

  def flush_db
    @delete_cache.each_key do
      |key|
      @db.delete(key)
    end
    
    for key, value in @write_cache
      @db[key] = value
    end
    @db.flush
    @write_cache.clear
  end
  private :flush_db

  def close(opt = CLEAR_READ_CACHE)
    @mode = nil
    flush_db
    @read_cache.clear unless opt == HOLD_READ_CACHE
    @db.close
    @db = nil

    @transaction_mode = nil
    disable_transactional_methods
  end
  private :close

  def close_with_no_flush
    @mode = nil
    @read_cache = nil
    @write_cache = nil
    @delete_cache = nil

    @db.close
    @db = nil

    @transaction_mode = nil
    disable_transactional_methods
  end
  private :close_with_no_flush

  
  #---------------------------------------
  #
  # Transaction  -
  #
  #-----------------------------------------------------------
  class Transaction

    extend Exception2MessageMapper
    def_exception(:ErrNoStartedTransaction, 
		  "Transaction is not started yet.")
    def_exception(:ErrClosedTransaction, 
		  "Transaction is closed already.")

    NO_START = :ObjectDBM__TXN_NO_START
    START = :ObjectDBM__TXN_START
    ABORTING = :ObjectDBM__TXN_ABORTING
    COMMITING = :ObjectDBM__TXN_COMMITING
    COMMITED = :ObjectDBM__TXN_COMMITED
    ABORTED = :ObjectDBM__TXN_ABORTED

    def initialize(odbm, m, outer = nil)
      @odbm = odbm
      @mode = m
      @outer = outer

      @status = NO_START
    end

    attr :mode
    attr :outer, true
    attr :read_cache, true
    attr :write_cache, true
    attr :delete_cache, true
  end

  
  #---------------------------------------
  #
  # StaticTransaction  -
  #     ObjectDBM#transaction {...} -- トランザクションの開始
  #	abort			    -- アボート
  #	checkpoint		    -- トランザクションを終了せずにコ
  #				       ミットする
  # トランザクションの動作:
  # commit: ブロックを正常に終了した時(throw/returnを含む)は, その子ト
  # 	    ランザクションを含めてすべてcommitする.
  # fail:   failして終了した時は, その子トランザクションを含めてすべて
  #	    abortする.
  # abort: 明示的にabortした時は, その子トランザクションを含めすべて
  # 	   abortする.
  #
  #-----------------------------------------------------------
  class StaticTransaction < Transaction
    ABORT_LABEL = "ObjectDBM__TXN_ABORT_LABEL"

    def initialize(odbm, m, outer)
      super
    end

    def transaction
      @status = START
      begin
#	txn, value = catch(ABORT_LABEL){[nil, yield(@current_transaction)]}
	txn, value = catch(ABORT_LABEL){[nil, yield(self)]}
	if txn
	  @status = ABORTING
	  unless txn.equal?(self)
	    throw ABORT_LABEL, [txn, value]
	  end
	end
	value
      rescue
	# 例外が発生した時
	@status = ABORTING
	fail

      ensure
	case @status
	when NO_START
	  Transaction.Fail ErrNoStartedTransaction

	when START
	  @status = COMMITED
	  @odbm.commit(self)

	when ABORTING
	  @status = ABORTED
	  @odbm.abort(self)

	when ABORTED, COMMITED
	  
	  Transactoin.Fail ErrClosedTransaction
	end
      end
    end
      
    def abort(value = nil)
      throw ABORT_LABEL, [self, value]
    end
    public :abort

    def checkpoint
      case @status
      when START
	@odbm.flush(self)
      when COMMITED, ABORTED
	Transaction.Fail ErrClosedTransaction
      end
    end
  end

  
  #---------------------------------------
  #
  # DynamicTransaction  -
  #     ObjectDBM#transaction	-- トランザクションの開始
  #	abort			-- アボート
  #	checkpoint		-- トランザクションを終了せずにコミッ
  #				   トする.
  #     commit			-- トランザクションをコミットして終了
  #     			   する.
  # 
  # 入れ子トランザクションの時の動作:
  # commit: 指定のトランザクションの子トランザクションをすべてコミット
  # 	    する. 
  # abort:  指定のトランザクションの子トランザクションをすべてアボート
  # 	    トする. 
  #
  #-----------------------------------------------------------
  class DynamicTransaction < Transaction
    def start
      @status = START
    end

    def commit
      case @status
      when START
	txn = @odbm.current_transaction
	while (txn.equal?(self))
	  @status = COMMITED
	  txn = txn.outer
	end
	@odbm.commit(self)
      when COMMITED, ABORTED
	Transaction.Fail ErrClosedTransaction
      end
    end

    def checkpoint
      case @status
      when START
	@odbm.flush(self)
      when COMMITED, ABORTED
	Transaction.Fail ErrClosedTransaction
      end
    end

    def abort
      case @status
      when START
	txn = @odbm.current_transaction
	until(txn.equal?(self))
	  txn.status = ABORTED
	  txn = txn.outer
	end
	@status = ABORTED

	@odbm.abort(self)
      when COMMITED, ABORTED
	Transaction.Fail ErrClosedTransaction
      end
    end
    public :abort
  end

  class DB_Adapter
    # open database named <name>
    def self.open(name)
      new(name)
    end

    def initialize(name)
      ODBM.Fail ErrAdapterInterfaceNotImplement, "initialize"
      #@db
    end

    # restore value with <key> 
    def [](key)
      ODBM.Fail ErrAdapterInterfaceNotImplement, "[]"
    end

    # store value with <key>
    def []=(key, value)
      ODBM.Fail ErrAdapterInterfaceNotImplement, "[]="
    end

    # testing for which the db have a key <key>
    def has_key?(key)
      @db.each_key do
	|k|
	return true if k == key
      end
    end
    alias key? has_key?
    alias include? has_key?
    
    # access all assoc in database.
    def each(&block)
      @db.each_key{|key|yield key, @db[key]}
    end

    # access all keys in database.
    def each_key(&block)
      ODBM.Fail ErrAdapterInterfaceNotImplement, "each_key"
    end

    # access all values in database.
    def each_value(&block)
      @db.each_key{|key|yield @db[key]}
    end

    # delete value with <key>
    def delete(key)
      ODBM.Fail ErrAdapterInterfaceNotImplement, "delete"
    end

    # flush database
    def flush
      ODBM.Fail ErrAdapterInterfaceNotImplement, "flush"
    end

    # close database
    def close
      ODBM.Fail ErrAdapterInterfaceNotImplement, "close"
    end
  end

  module HashLikeInterface
    
    def db
      ODBM.Fail ErrAdapterInterfaceNotImplement, "db"
    end

    def [](key)
      materialize_value(db[key])
    end

    def []=(key, value)
      db[key] = serialize_value(value)
    end

    def has_key?(key)
      db.key?(key)
    end

    def each
      db.each{|k, v| yield k, materialize_value(v)}
    end

    def each_key(&block)
      db.each_key &block
    end

    def each_value
      db.each_value{|v| yield materialize_value(v)}
    end

    def delete(key)
      db.delete(key)
    end

    def serialize_value(v)
      ODBM.Fail ErrAdapterInterfaceNotImplement, "serialize_value(v)"
    end
    def materialize_value(v)
      ODBM.Fail ErrAdapterInterfaceNotImplement, "materialize_value(v)"
    end
  end

  autoload :DBM, "dbm"
  class DBM_Adapter<DB_Adapter
    
    include HashLikeInterface

    def initialize(name)
      @db = DBM.open(name)
    end

    def db
      @db
    end

    def serialize_value(v)
      Marshal.dump(v)
    end

    def materialize_value(v)
      return v unless v
      Marshal.load(v)
    end

    def flush
      # noop
    end

    def close
      flush
      @db.close
      @db = nil
    end

  end

  autoload :GDBM, "gdbm"
  class GDBM_Adapter<DBM_Adapter
    def initialize(name)
      @db = GDBM.open(name)
    end

    def flush
      @db.sync
    end
  end

  autoload :SDBM, "sdbm"
  class SDBM_Adapter<DBM_Adapter
    def initialize(name)
      @db = SDBM.open(name)
    end
  end

  class PHash_Adapter<DB_Adapter
    include HashLikeInterface

    def initialize(name)
      @db_name = name
      if File.exist?(name)
        file = File::open(name, 'r')
	begin
	  @hash = Marshal.load(file)
	ensure
	  file.close
	end
      else
        @hash = {}
      end
    end

    def db
      @hash
    end
    def serialize_value(v)
      v
    end

    def materialize_value(v)
      v
    end

    # commit database
    def flush
      newfile = @db_name + '.new'
      file = open(newfile, 'w')
      Marshal.dump(@hash, file)
      file.close
      File.rename(newfile, @db_name)
    end

    # close database
    def close
      flush
      @hash = nil
    end
  end

  class VDB_Adapter<DB_Adapter
    include HashLikeInterface

    VDBS = {}

    def initialize(name)
      @db_name = name
      @hash = VDBS[@db_name]
      @hash = {} unless @hash
    end

    def db
      @hash
    end
    def serialize_value(v)
      v
    end

    def materialize_value(v)
      v
    end

    # commit database
    def flush
      VDBS[@db_name] =  @hash
    end

    # close database
    def close
      flush
      @hash = nil
    end
  end
end
