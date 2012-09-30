module doodle.core.undo;

import std.array;
import std.datetime;

// An abstract framework for undo/redo.
// Assume the application works on one document at a time,
// therefore a single undo/redo history.
// Each change to the document is modelled as an Edit.
// Previous edits are represented by an undo stack
// and can be undone in order.
// As edits are undone the are placed on a redo stack
// and can be redone in order.
// As edits are redone the are placed on the undo stack, etc.
//
// When a new edit is made an attempt to merge it with
// the previous Edit is made. For example, typing characters
// in short succession generates many Edits that may be
// merged into one Edit.
// When a new edit is made the redo stack is cleared.
//
// Application code must generate Edits from user interaction.
// Typically application code will receive some input event and:
// * Attempt to perform an action,
// * If the action succeeds then encapsulate the action
//   in an Edit and add it to the undo manager.
// Note, not all interaction results in Edits, for example,
// changing the view, zooming/scrolling, etc are not edits
// and do not affect undo/redo

abstract class Edit {
    private {
        string _description;
        SysTime _timeStamp;
    }

    this(in string description) {
        _description = description;
        _timeStamp = Clock.currTime();
    }

    this(in string description, SysTime timeStamp) {
        assert(description);
        _description = description;
        _timeStamp = timeStamp;
    }

    string description() const { return _description; }
    const(SysTime) timeStamp() const { return _timeStamp; }

    final bool merge(Edit subsequent) {
        if (mergeImpl(subsequent)) {
            // Adopt the new timestamp and description
            _timeStamp = subsequent._timeStamp;
            _description = subsequent._description;
            return true;
        }
        else {
            return false;
        }
    }

    void undo();
    void redo();
    protected bool mergeImpl(Edit subsequent) { return false; }
}

interface IUndoManagerObserver {
    // Each description is null if the associated bool is false
    void undoRedoUpdate(in bool canUndo, in string undoDescription,
                        in bool canRedo, in string redoDescription);
}

// XXX This interface doesn't appear to add any value
interface IUndoManager {
    void addEdit(Edit edit);
    void undo();
    void redo();
    void reset();

    void addObserver(IUndoManagerObserver observer);
    void removeObserver(IUndoManagerObserver observer);
}

class UndoManager : IUndoManager {
    this(int maxUndoLevel = -1) {
        _maxUndoLevel = maxUndoLevel;
    }

    ~this() {
        assert(_observers.length == 0);
    }

    void addEdit(Edit edit) {
        _redoEdits.length = 0;

        if (_undoEdits.empty || !_undoEdits.back.merge(edit)) {
            _undoEdits ~= edit;
            if (_maxUndoLevel >= 0 && _undoEdits.length > _maxUndoLevel) {
                _undoEdits.length = _undoEdits.length - 1;
            }
        }

        notifyObservers();
    }

    void undo() {
        assert(canUndo());
        auto edit = _undoEdits.back;
        edit.undo();
        _undoEdits.popBack();
        _redoEdits ~= edit;

        notifyObservers();
    }

    void redo() {
        assert(canRedo());
        auto edit = _redoEdits.back;
        edit.redo();
        _redoEdits.popBack();
        _undoEdits ~= edit;

        notifyObservers();
    }

    bool canUndo() const { return !_undoEdits.empty; }
    bool canRedo() const { return !_redoEdits.empty; }

    void reset() {
        _undoEdits.length = _redoEdits.length = 0;
        notifyObservers();
    }

    void addObserver(IUndoManagerObserver observer) {
        _observers ~= observer;
    }

    void removeObserver(IUndoManagerObserver observer) {
        // NYI
    }

    // IUndoManager overrides:

    private {
        int _maxUndoLevel;
        Edit[] _undoEdits;
        Edit[] _redoEdits;
        IUndoManagerObserver[] _observers;          // FIXME, use a different container

        void notifyObservers() {
            foreach (o; _observers) {
                o.undoRedoUpdate(canUndo(), canUndo() ? _undoEdits.back.description() : null,
                                 canRedo(), canRedo() ? _redoEdits.back.description() : null);
            }
        }
    }
}
