;; -*- lexical-binding: t -*-

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(defun omnisharp--run-all-tests-in-class ()
  (interactive)
  (omnisharp--current-buffer-project
    (lambda (project-framework)
      (omnisharp--current-file-members-as-tree
        (lambda (file-members)
          (if
            (or
              (equal nil file-members)
              (equal 0 (length file-members)))
            (message "omnisharp: No Test Methods to run")
            (let* (
                    (raw-test-type (alist-get 'Name (-first-item file-members)))
                    (test-method-names (-map (lambda (d) (alist-get 'Data d)) file-members))
                    (test-type (cdr (assoc raw-test-type '(
                                                       ("XunitTestMethod" . "xunit")
                                                       ("MSTestMethod" . "mstest")
                                                       ("NunitTestMethod" . "nunit")
                                                       ))))
                    (request-message (-concat
                                       (omnisharp--get-request-object)
                                       `((TestFrameworkName . ,test-type)
                                          (TargetFrameworkVersion . ,project-framework)
                                          (MethodNames . ,(vconcat test-method-names))
                                          )
                                     )
                      ))
              ;;(message (json-encode request-message))
              (omnisharp--send-command-to-server "/v2/runtestsinclass"
                request-message
                (lambda (resp) (message "%s" resp))
                )


              ))))
      ))
  )

(defun omnisharp--get-class-declarations-from-response (response)
  (-filter (lambda (x)
             (equal "ClassDeclaration" (alist-get 'Kind x)))
           (omnisharp--vector-to-list (alist-get 'TopLevelTypeDefinitions response))))

(defun omnisharp--get-test-info-for-class (classes)
  (-map
    (-lambda (info) info)
    (omnisharp--vector-to-list
      (-mapcat
        (lambda (x3) (alist-get 'Features x3))
        (-filter
          (lambda (x2) (equal "MethodDeclaration" (alist-get 'Kind x2)))
          (-mapcat
            (lambda (x1) (omnisharp--vector-to-list (alist-get 'ChildNodes x1)))
            classes)
          )))
    )
  )

(defun omnisharp--current-file-members-as-tree (callback)
  (omnisharp--send-command-to-server-sync
    "/currentfilemembersastree"
    (omnisharp--get-request-object)
    (-lambda (response)
      (funcall callback (omnisharp--get-test-info-for-class
                          (omnisharp--get-class-declarations-from-response
                            response)))))
  )

(defun omnisharp--current-buffer-project (callback)
  (omnisharp--send-command-to-server
    "/project"
    (omnisharp--get-request-object)
    (lambda (response)
      (funcall callback (omnisharp--get-project-framework response)
        )))
  )

(defun omnisharp--get-project-framework (response)
  (alist-get 'TargetFramework (alist-get 'MsBuildProject response))
  )


(provide 'omnisharp-test-actions)
