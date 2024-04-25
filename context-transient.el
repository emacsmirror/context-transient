;;; context-transient.el --- Context specific transients -*- lexical-binding: t; -*-
;;
;; Copyright (c) 2024, Mykhaylo Bilyanskyy <mb@m1k.pw>
;;
;; Author: Mykhaylo Bilyanskyy <mb@m1k.pw>
;; Maintainer: Mykhaylo Bilyanskyy <mb@m1k.pw>
;; Version: 0.1
;; Package-Requires: ((emacs "29.1"))
;;
;; Created: 23 Apr 2024
;;
;; URL: https://github.com/licht1stein/context-transient.el
;;
;; License: GPLv3
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see
;; <http://www.gnu.org/licenses/>.
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;; Easily define and call context-specific transient menus for current
;; project, git repo, buffer or any other condition.
;;; Code:
(require 'transient)

(defgroup context-transient nil "Contextual transient menus."
  :group 'convenience)

(defcustom context-transient-hook nil
  "Hook run with `context-transient'.
Each element must be a function which returns nil (to be skipped),
or a symbol naming a `context-transient' menu.
Functions are run in order until the first non-nil result is returned."
  :type 'hook)

;;;###autoload
(defun context-transient-clear ()
  "Remove all previously defined transients from `context-transient-hook'."
  (interactive)
  (setq context-transient-hook nil)
  (message "All context transients removed."))

(defun context-transient--check-repo (repo-name)
  "Check if current repo name is REPO-NAME."
  (when repo-name
    (let* ((repo-dir (locate-dominating-file "." ".git")))
      (when-let* ((repo-dir (car (last (butlast (file-name-split repo-dir))))))
        (equal repo-dir repo-name)))))

(defun context-transient--check-buffer (buff)
  "Check if current buffer name is BUFF."
  (when buff
    (equal (buffer-name) buff)))

(defun context-transient--run-hook-collect-results (hook &rest args)
  "Run all functions in HOOK and collect non-nil results.
ARGS are passed to each hook function."
  (let ((results '()))
    ;; Loop through all functions in the hook
    (dolist (func (symbol-value hook))
      (let ((result (apply func args)))
        ;; Collect results that are not nil
        (when result
          (push result results))))
    ;; Return the collected results
    (nreverse results)))  ; Return results in the order they were added

;;@FIX: ensure returned transient is, in fact, a transient before running
;;;###autoload
(defun context-transient ()
  "Run context transient for the current context.

If more than one contexts apply, prompts to select which one to run."
  (interactive)
  (let ((transients (context-transient--run-hook-collect-results 'context-transient-hook)))
    (cond
     ((not transients) (user-error "No transient found for current context"))
     ((equal 1 (length transients)) (funcall (car transients)))
     (t (funcall (intern (completing-read "More than one context transients found:" transients)))))))

(cl-defun context-transient--check-conditions (&key repo buffer context project mode)
  "Check if any of the REPO, BUFFER or CONTEXT conditions are true."
  (or
   (and repo (context-transient--check-repo repo))
   (and buffer (context-transient--check-buffer buffer))
   (and context (macroexp-progn (list context)))
   (and project (equal project (project-name (project-current))))
   (and mode (equal mode major-mode))))

(context-transient--check-conditions :mode 'emacs-lisp-mode)

(defun context-transient--symbol-concat (prefix name)
  "Concat PREFIX string with symbol NAME and return resulting symbol."
  (intern (concat prefix (symbol-name name))))

;;@FIX: Don't eval NAME arg twice.
;;@MAYBE: Don't require keyword arg for menu definition.
(cl-defmacro context-transient-define (name &key doc menu context repo buffer project mode)
  "Define a transient MENU with NAME with DOC and DEFINITION to run in CONTEXT.

The resulting transient will be called `context-transient/NAME'"
  (let ((count (length (remove nil (list context repo buffer project mode))))
        (docstring (concat "Automatically generated function to check if `context-transient' conditions are currently met for " (symbol-name name)))
        (fn-name (context-transient--symbol-concat "context-transient-check/" name))
        (transient-name (context-transient--symbol-concat "context-transient/" name)))
    ;; Check if the count is not exactly one
    (when (/= count 1)
      (user-error "Exactly one of :context, :repo, :project or :buffer must be provided"))
    (declare (indent 1))
    `(progn
       (transient-define-prefix ,transient-name () ,doc ,menu)
       (defun ,fn-name nil
        ,docstring
        (when
            (context-transient--check-conditions
             :repo ,repo
             :buffer ,buffer
             :context ,context
             :project ,project
             :mode ,mode)
          ',transient-name))
       (unless (memq ',fn-name context-transient-hook)
        (add-hook 'context-transient-hook (function ,fn-name))))))

;; (context-transient-define context-transient-repo
;;   :doc "Repo specific transient"
;;   :project "context-transient.el"
;;   :menu
;;   [["Test" ("b" "This is repo context" (lambda () (interactive) (message "Repo context!")))]])

(provide 'context-transient)
;;; context-transient.el ends here
