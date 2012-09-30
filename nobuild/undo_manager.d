module doodle.main.undo_manager;

class UndoManager : IUndoManager {
    this() {
    }

    void addObserver(IUndoObserver observer) {
        _observers.add(observer);
    }

    void removeObserver(IUndoObserver observer) {
        _observers.remove(observer);
    }

    void reset() {
        assert(!inTransaction());
        _past.clear();
        _future.clear();
        foreach(IUndoObserver obs; _observers) {
            obs.canUndo(false, "");
            obs.canRedo(false, "");
        }
    }

    void undo() {
        assert(canUndo());
        Transaction t = _past.pop();
        t.undo();
        _future.push(t);
    }

    void redo() {
        assert(canRedo());
        Transaction t = _future.pop();
        t.redo();
        _past.push(t);
    }

    bool canUndo() {
        assert(!inTransaction());
        return !_past.empty();
    }

    bool canRedo() {
        assert(!inTransaction());
        return !_future.empty();
    }

    void beginTransaction(char[] description) {
        assert(!inTransaction());
        _current_transaction = new Transaction(description);
    }

    void cancelTransaction() {
        assert(inTransaction());
        _current_transaction.cancel();
        _current_transaction = null;
    }

    void endTransaction() {
        assert(inTransaction());
        _current_transaction.finalise();

        if (!_future.empty()) {
            _future.clear();
            foreach(IUndoObserver obs; _observers) {
                obs.canRedo(false, "");
            }
        }

        _past.push(_current_transaction);

        foreach(IUndoObserver obs; _observers) {
            bs.canUndo(true, _current_transaction.name());
        }

        _current_transaction = null;
    }

    // IUndoManager implementations:

    void addAction(Action action) {
        assert(inTransaction());
        _current_transaction.add(action);
    }

    private {
        bool inTransaction() {
            return _current_transaction !is null;
        }

        class Transaction {
            enum State {
                Accumulating,
                Finalised,
                Canceled
            }

            this(char[] description) {
                _description = description;
                _state = Accumulating;
            }

            char[] description() {
                return _description;
            }

            void add(Action action) {
                assert(_state == State.Accumulating);
                _actions.addTail(action);
            }

            void finalise() {
                assert(_state == State.Accumulating);
                assert(!_actions.empty());
                _finalised = true;
            }

            void cancel() {
                assert(_state == State.Accumulating);
                foreach_reverse(UndoAction ua; _actions) {
                    ua.undo();
                }
            }

            void redo() {
                assert(_finalised);
                foreach (UndoAction ua; _actions) {
                    ua.redo();
                }
            }

            void undo() {
                assert(_finalised);
                foreach_reverse(UndoAction ua; _actions) {
                    ua.undo();
                }
            }

            private {
                char[] _description;
                List!(Action) _actions;
                State _state;
            }
        }

        Transaction _current_transaction;
        Stack!(Transaction) _past;
        Stack!(Transaction) _future;
        Set!(IUndoObserver) _observers;
    }
}
