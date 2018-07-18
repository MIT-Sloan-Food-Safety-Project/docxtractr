#' Read in a Word document for table extraction
#'
#' Local file path or URL pointing to a \code{.docx} file. Can also take
#' \code{.doc} file as input if \code{LibreOffice} is installed
#' (see \url{https://www.libreoffice.org/} for more info and to download).
#'
#' @param path path to the Word document
#' @importFrom xml2 read_xml
#' @export
#' @examples
#' doc <- read_docx(system.file("examples/data.docx", package="docxtractr"))
#' class(doc)
#' \dontrun{
#' # from a URL
# budget <- read_docx(
# "http://rud.is/dl/1.DOCX")
#' }
read_docx <- function(path) {

  stopifnot(is.character(path))

  # make temporary things for us to work with
  tmpd <- tempdir()
  tmpf <- tempfile(tmpdir=tmpd, fileext=".zip")

  # Check to see if input is a .doc file
  is_input_doc <- is_doc(path)

  # If input is a .doc file, create a temp .doc file
  if (is_input_doc) {
    lo_assert()
    tmpf_doc <- tempfile(tmpdir = tmpd, fileext = ".doc")
    tmpf_docx <- gsub("\\.doc$", ".docx", tmpf_doc)
  } else {
    tmpf_doc <- NULL
    tmpf_docx <- NULL
  }

  on.exit({ #cleanup
    unlink(tmpf)
    unlink(tmpf_doc)
    unlink(tmpf_docx)
    unlink(sprintf("%s/docdata", tmpd), recursive=TRUE)
  })

  if (is_url(path)) {
    if (is_input_doc) {
      # If input is a url pointing to a .doc file, write file to disk
      res <- httr::GET(path, write_disk(tmpf_doc))
      httr::stop_for_status(res)

      # Save .doc file as a .docx file using LibreOffice command-line tools.
      convert_doc_to_docx(tmpd, tmpf_doc)

      # copy output of LibreOffice to zip (not entirely necessary)
      do_file_copy(tmpf_docx, tmpf)
    } else {
      # If input is a url pointing to a .docx file, write file to disk
      res <- httr::GET(path, write_disk(tmpf))
      httr::stop_for_status(res)
    }
  } else {
    path <- path.expand(path)
    if (!fs::is_file(path)) stop(sprintf("Cannot find '%s'", path), call.=FALSE)

    # If input is a .doc file, save it as a .docx file using LibreOffice
    # command-line tools.
    if (is_input_doc) {
      do_file_copy(path, tmpf_doc)
      convert_doc_to_docx(tmpd, tmpf_doc)

      # copy output of LibreOffice to zip (not entirely necessary)
      do_file_copy(tmpf_docx, tmpf)
    } else {
      # Otherwise, if input is a .docx file, just copy docx to zip
      # (not entirely necessary)
      do_file_copy(path, tmpf)
    }
  }

  # unzip it
  unzip(tmpf, exdir=sprintf("%s/docdata", tmpd))

  # read the actual XML document
  doc <- xml2::read_xml(sprintf("%s/docdata/word/document.xml", tmpd))

  # extract the namespace
  ns <- xml2::xml_ns(doc)

  # get the tables
  tbls <- xml2::xml_find_all(doc, ".//w:tbl", ns=ns)

  if (file.exists(sprintf("%s/docdata/word/comments.xml", tmpd))) {
    docmnt <- read_xml(sprintf("%s/docdata/word/comments.xml", tmpd))
    # get the comments
    cmnts <- xml2::xml_find_all(docmnt, ".//w:comment", ns=ns)
  } else {
    cmnts <- xml2::xml_find_all(doc, ".//w:comment", ns=ns)
  }

  # make an object for other functions to work with
  docx <- list(docx=doc, ns=ns, tbls=tbls, cmnts=cmnts, path=path)

  # special class helps us work with these things
  class(docx) <- "docx"

  docx

}
