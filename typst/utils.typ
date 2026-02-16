
#let my-date(..args) = {
  let date = if args.pos().len() == 0{
    datetime.today()
  } else {
    args.pos().first()
  }

  let day = date.day()
  let suffix = if day in (11, 12, 13) { "th" } else {
    ("st", "nd", "rd").at(calc.rem(day - 1, 10), default: "th")
  }

  let month-year = date.display("[month repr:long], [year]") 
  
  [#day#super[#suffix] #month-year]
}

#let parse-thm-args(env-name, args) = {
  let content-label = none
  let ref-label = none
  let has-proof = true

  if "content-label" in args.named() {
    content-label = args.named().at("content-label")
  }

  if "has-proof" in args.named(){
    has-proof = args.named().at("has-proof")
  }

  if "ref-label" in args.named(){
    ref-label = args.named().at("ref-label")
  }
  
  let pos = args.pos()
  let content = pos.last()

  let ref-label-regex = regex("^[a-zA-Z0-9]+-[a-zA-Z0-9\-]*$")

  let remaining = pos.slice(0, -1)  // exclude content

  for arg in remaining {
    if type(arg) == bool {
      has-proof = arg
    } else {
      let arg-str = str(arg)
      if ref-label == none and arg-str.match(ref-label-regex) != none {
        ref-label = arg-str
      } else if content-label == none {
        content-label = arg-str
      }
    }
  }

  if ref-label != none {
    let env-prefix = lower(env-name)
    if not ref-label.starts-with(env-prefix + "-") {
      ref-label = env-prefix + "-" + ref-label
    }
  }

  (content-label: content-label, ref-label: ref-label, has-proof: has-proof, content: content)
}

#let parse-solution-args(args) = {
  let content = none
  let is-proof = true
  
  if "is-proof" in args.named(){
    is-proof = args.named().at("is-proof")
  }
  
  let pos = args.pos()
  if pos.len() == 1 {
    content = pos.at(0)
  } else if pos.len() == 2 {
    is-proof = pos.at(0)
    content = pos.at(1)
  }
  
  (is-proof: is-proof, content: content)
}

#let parse-problem-args(env-name, args) = {
  let content-label = none
  let marks = none
  let ref-label = none
  
  if "content-label" in args.named() {
    content-label = args.named().at("content-label")
  }

  if "ref-label" in args.named(){
    ref-label = args.named().at("ref-label")
  }

  if "marks" in args.named() {
    marks = args.named().at("marks")
  }

  let pos = args.pos()
  let content = pos.last()

  let ref-label-regex = regex("^[a-zA-Z0-9]+-[a-zA-Z0-9\-]*$")
  let marks-regex = regex("^(?:[0-9+\-\s\(\)\/\=]|times)*$")

  let remaining = pos.slice(0, -1)  // exclude content

  for arg in remaining {
    let arg-str = str(arg)
    if ref-label == none and arg-str.match(ref-label-regex) != none {
      ref-label = arg-str
    } else if marks == none and arg-str.match(marks-regex) != none {
      marks = arg-str
    } else if content-label == none {
      content-label = arg-str
    }
  }

  if ref-label != none {
    let env-prefix = lower(env-name)
    if not ref-label.starts-with(env-prefix + "-") {
      ref-label = env-prefix + "-" + ref-label
    }
  }
  
  (content-label: content-label, marks: marks, content: content, ref-label: ref-label)
}

#let process-marks(marks) = {
  if marks != none { 
    let processed = marks.replace("times", "*")
    processed = processed.replace(regex("(\d+)\s+(\d+)/(\d+)"), m => {
      let whole = m.captures.at(0)
      let numerator = m.captures.at(1)
      let denominator = m.captures.at(2)
      "(" + whole + "+" + numerator + "/" + denominator + ")"
    })
    let eval_val = eval(processed)
    if processed != str(eval_val){
      return [#eval(marks, mode: "math") = $#eval_val$]
    } else {
      return [$#marks$]
    }
  }
}

#let focus(content) = {
  text(fill:purple, style:"italic")[#content]
}

#let redact(content) = {
  set heading(outlined: false)
  show text:none
  show math.equation:none
  show box: none
  show block: none
  show grid: none
  show image: none
  show align: none
  show v: none
  show pagebreak: none
  show colbreak: none
  content
  // v(-1fr)
}

