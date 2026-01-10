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

#let parse-thm-args(args) = {
  let content-label = none
  let content = none
  let has-proof = true

  if "content-label" in args.named() {
    content-label = args.named().at("content-label")
  }

  if "has-proof" in args.named(){
    has-proof = args.named().at("has-proof")
  }
  
  let pos = args.pos()
  if pos.len() == 1 {
    content = pos.at(0)
  } else if pos.len() == 2 {
    if type(pos.at(0)) == bool {
      has-proof = pos.at(0)
      content = pos.at(1)
    } else {
      content-label = pos.at(0)
      content = pos.at(1)
    }
  } else if pos.len() == 3 {
    content-label = pos.at(0)
    has-proof = pos.at(1)
    content = pos.at(2)
  }
  
  (content-label: content-label, content: content, has-proof: has-proof)
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

#let parse-problem-args(args) = {
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
  
  // if pos.len() > 1 {
  //   content-label = pos.at(0)
  //   if pos.len() > 2{
  //     marks = pos.at(1)
  //   }
  // }
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
      return [#h(1fr) #eval(marks, mode: "math") = $#eval_val$]
    } else {
      return [#h(1fr) $#marks$]
    }
  }
}

#let focus(content) = {
  text(fill:purple, style:"italic")[#content]
}

