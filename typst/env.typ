#import "utils.typ": *

#let instructor-name = "Aritra Bhowmick"
#let course-name = "Algebraic Topology II (KSM4E02)"

#let daynote-counter = counter("daynote")
#let thm-counter = counter("theorem")

#let show-quiz = true
#let show-assignment = true
#let show-marks = true

#let problem-counter = counter("problem")

#let problems-content = state("problems-content", (:))
#let problems-label = state("problems", ())

#let assignments = json("assignments.json")

#let assignment-index = if "assignment-index" in sys.inputs {
  eval(sys.inputs.at("assignment-index"))
} else {
  -1
}

#let selected-assignment = none
#let assignment-name = ""
#let assignment-date = ""
#let assignment-deadline = ""
#let assignment-note = ""

#if assignment-index > -1 {
  selected-assignment = assignments.at(assignment-index)
}
// #let selected-assignment = assignments.at(2)

#let show-hints = if "show-hints" in sys.inputs {
  eval(sys.inputs.at("show-hints"))
} else {
  true
}

#let show-proofs = if "show-proofs" in sys.inputs {
  eval(sys.inputs.at("show-proofs"))
} else {
  true
}

#let fancy-mode = if "fancy-mode" in sys.inputs {
  eval(sys.inputs.at("fancy-mode"))
} else {
  true
}

#let assignment-mode = if "assignment-mode" in sys.inputs {
  eval(sys.inputs.at("assignment-mode"))
} else {
  false
}

#let daynote-mode = if "daynote-mode" in sys.inputs {
  eval(sys.inputs.at("daynote-mode"))
} else {
  false
}

#let daynotes-to-show = if "daynotes-to-show" in sys.inputs {
  let val = eval(sys.inputs.at("daynotes-to-show"))
  if type(val) == "array" {
    val
  } else {
    (val,)
  }
} else {
  ()
}

#let problems-to-show = ()

#if selected-assignment != none {
  assignment-name = selected-assignment.name
  let d = selected-assignment.date
  assignment-date = datetime(year: d.year, month: d.month + 1, day: d.day)
  let d = selected-assignment.deadline
  assignment-deadline = datetime(year: d.year, month: d.month + 1, day: d.day)
  problems-to-show = selected-assignment.labels
}

#if daynotes-to-show.len() != 0 {
  daynote-mode = true
}

#if problems-to-show.len() != 0 {
  assignment-mode = true
}

#if daynote-mode {
  show-quiz = false
  show-assignment = false
}

#if assignment-mode {
  fancy-mode = false
}

#let daynote-title() = {
  if not assignment-mode {
    align(center)[
      #text(size:12pt)[Course notes for] \
      #v(0.1em)
      #text(size:20pt, fill: blue)[#course-name] \
      #v(1em)
      Instructor: #instructor-name \
      #v(1em)
      #line(length: 50%, stroke: blue + 1pt)
      #v(1em)
    ]
  }
}

// #let daynotes-to-show = (3,)
#let daynote(date: datetime.today(), tags: "", content) = {
  daynote-counter.step() 
  thm-counter.update(0)
  let daynote-content = context[
    #let current = daynote-counter.at(here()).at(0)
    #problems-label.update(old => (
      ..old,
      (
        daynote: current, 
      )
    ))
    #if daynotes-to-show.len() == 0 or daynotes-to-show.contains(current){
      block[
        = Day #daynote-counter.display() #box[#move(dy: -.1em)[:]] #my-date(date)
        
        #if tags != "" {
          v(0.5em)
          text(font: "DejaVu Sans Mono", size:0.75em)[#eval(tags, mode: "markup")]
          v(0.5em)
        }
        #line(length: 100%, stroke: blue + 0.5pt)
        #v(0.5em)
        #content
      ]
      // colbreak()
    } else {
      // set heading(outlined: false)
      box(height: 0pt, clip:true)[
        #content
      ]
    }
  ]
  if assignment-mode {
    set heading(outlined: false)
    box(height: 0pt, clip:true)[#daynote-content]
    v(-1fr)
    // box(width: 0pt, height: 0pt, clip:true)[#daynote-content]
  } else {
    daynote-content
  }
}

#let thm-env(env-name, color, ..args) = {
  if assignment-mode {
    return
  }
  let parsed = parse-thm-args(env-name, args)
  let content-label = parsed.content-label
  let ref-label = parsed.ref-label
  let has-proof = parsed.has-proof
  let content = parsed.content

  thm-counter.step()

  let styled-block = block(
    spacing: 1em,
    radius: if has-proof { (top: 4pt, bottom: 0pt) } else { 4pt },
    below: if has-proof { 0pt } else { auto }
  )[
      #block(
        fill: color.lighten(40%),
        width: 100%,
        inset: 8pt,
        stroke: color,
        radius: (top: 4pt),
        sticky: true,
      )[
        #context [
          *#env-name #daynote-counter.display().#thm-counter.display()#box[#move(dy: -.1em)[:]]*
          #if content-label != none [
            (#emph[#eval(content-label, mode: "markup")])
          ]
        ]
      ]
      #block(
        fill: color.lighten(80%),
        above: 0pt,
        inset: 12pt,
        width: 100%,
        radius: (bottom: 0pt),
        stroke: if has-proof { (top : none, rest : color) } else { (top : none, bottom : none, rest : color) },
        breakable: true,
      )[  
        #content
      ]
      #if not has-proof or not show-proofs {
        block(fill: color.lighten(80%),
          width: 100%,
          stroke: ( top : none, rest: color ),
          radius: (bottom : 4pt),
          above: -1pt,
          height: 4pt,
          inset: 12pt,
          breakable: false,
        )[]
      }
  ]

  let plain-block = block(
    breakable: true,
    spacing: 1em,
  )[
      #block(
        width: 100%,
        inset: 0pt,
        sticky: true,
      )[
        #context [
          *#env-name #daynote-counter.display().#thm-counter.display()#box[#move(dy: -.1em)[:]]*
          #if content-label != none [
            (#eval(content-label, mode: "markup"))
          ]
        ]
      ]
      #block(
        above: 0pt,
        inset: 10pt,
        width: 100%,
      )[  
        #content
      ]
  ]

  let content-block = if fancy-mode { styled-block } else { plain-block }
  
  // This is needed for referencing to work in the document
  show figure: set block(breakable: true, sticky: has-proof)
  // show figure: set block(sticky: has-proof)
  let fig = figure(align(left, content-block), kind: "thm-like", supplement: env-name, numbering: n => numbering("1.1", daynote-counter.get().first(), thm-counter.get().first()))
  if ref-label == none {
    fig
  } else {
    [#fig #label(ref-label)]
  }
}

#let problem-env(env-name, color, visible: true, ..args) = {
  let parsed = parse-problem-args(env-name, args)
  
  let content-label = parsed.content-label
  let ref-label = parsed.ref-label
  let marks = parsed.marks
  let content = parsed.content

  if ref-label != none {
    context{
      let current = daynote-counter.at(here()).at(0)
      problems-label.update(old => (
        ..old,
        (
          daynote: current, 
          ref-label: ref-label,
        )
      ))
    }
  }

  if assignment-mode {
    if ref-label != none and (problems-to-show.len() == 0 or ref-label in problems-to-show) {
      problems-content.update(old => (
        ..old,
        (ref-label): (
          content-label: content-label,
          marks: marks,
          content: content
        )
      ))
    }
    return
  }

  if not visible { return }

  thm-counter.step()

  let styled-block = block(
    breakable: true,
    spacing: 1em,
  )[
      #block(
        fill: color.lighten(40%),
        width: 100%,
        inset: 8pt,
        stroke: color,
        radius: (top: 4pt),
        sticky: true,
      )[
        #context [
          *#env-name #daynote-counter.display().#thm-counter.display()#box[#move(dy: -.1em)[:]]*
          #if content-label != none [
            (#emph[#eval(content-label, mode: "markup")])
          ]
          #if show-marks {
            process-marks(marks)
          }
        ]
      ]
      #block(
        fill: color.lighten(80%),
        above: 0pt,
        inset: 12pt,
        width: 100%,
        below: -0.5pt,
        stroke: (top : none, bottom : none, rest : color),
        breakable: true,
        sticky: true,
      )[  
        #content
      ]
      #block(fill: color.lighten(80%),
        width: 100%,
        stroke: ( top : none, rest: color ),
        radius: (bottom : 4pt),
        above: -1pt,
        height: 4pt,
        inset: 12pt,
        breakable: false,
      )[]
  ]

  let plain-block = block(
    breakable: true,
    spacing: 1em,
  )[
      #block(
        width: 100%,
        inset: 0pt,
        sticky: true,
      )[
        #context [
          *#env-name #daynote-counter.display().#thm-counter.display()#box[#move(dy: -.1em)[:]]*
          #if content-label != none [
            (#eval(content-label, mode: "markup"))
          ]
        ]
      ]
      #block(
        above: 0pt,
        inset: 10pt,
        width: 100%,
        breakable: true,
      )[  
        #content
        #process-marks(marks)
      ]
  ]

  let content-block = if fancy-mode { styled-block } else { plain-block }
  
  // This is needed for referencing to work in the document
  show figure: set block(breakable: true)
  let fig = figure(align(left, content-block), kind: "problem-like", supplement: env-name, numbering: n => numbering("1.1", daynote-counter.get().first(), thm-counter.get().first()))
  if ref-label == none {
    fig
  } else {
    [#fig #label(ref-label)]
  }
}

#let solution-env(env-name, color, ..args) = {
  let parsed = parse-solution-args(args)

  let is-proof = parsed.is-proof
  let content = parsed.content

  if assignment-mode and is-proof {
    return
  }

  if (not is-proof and show-hints) or (is-proof and show-proofs) {
    if fancy-mode {
      block(
          fill: color.lighten(80%),
          inset: 12pt,
          width: 100%,
          radius: if is-proof { (bottom: 0pt) } else { 4pt },
          above: if is-proof { 0pt } else { auto },
          below: if is-proof { -0.5pt } else { auto },
          stroke: if is-proof { (bottom : none, top : none, rest : color) } else { color },
      )[  
        *#underline(env-name) #box[#move(dy: -.1em)[:]]* #content
        #if is-proof {
          h(1fr); $square$
        }
      ]
      if is-proof {
        block(fill: color.lighten(80%),
          width: 100%,
          stroke: ( top : none, rest: color ),
          radius: (bottom : 4pt),
          above: -1pt,
          height: 4pt,
          inset: 12pt,
          breakable: false,
        )[]
      }
    } else {
      block[
        *#underline(env-name) #box[#move(dy: -.1em)[:]]* #content
        #if is-proof {
          h(1fr); $square$
        }
      ]
    }
  }
}

#let generic-problem(problem) = {
  let content-label = problem.content-label
  let marks = problem.marks
  let content = problem.content
  
  let content-block = block(
    breakable: true,
    spacing: 2em,
  )[
    #problem-counter.step()
    *Q#context(problem-counter.get().at(0)).*
    #if content-label != none {
      [(_#eval(content-label, mode:"markup")_)]
    }
    #content
    #if marks != none {
      v(0em)
      box[#h(1fr)#process-marks(marks)]
    }
  ]
  content-block
}

#let show-all-quizzes() = {
  if assignment-mode {
    context{
      align(center)[
        #text(size: 20pt)[#underline[#assignment-name]] \
        #v(0.1em)
        #text(size: 10pt)[(#assignment-date.display("[day] [month repr:long], [year]"))]
        #v(0.5em)
        #text(size: 12pt)[Submission Deadline: ] #text(fill:red, size: 15pt)[#assignment-deadline.display("[day] [month repr:long], [year]")]
        #v(0.7em)
        #text(size: 10pt)[Course: #course-name #h(1fr)
        Instructor: #instructor-name]
        #line(length: 100%)
      ]
      if assignment-note != "" [
        #underline[*Note:*] #assignment-note
      ]
      for (key, problem) in problems-content.get() {
        [#generic-problem(problem)]
      }
    }
  }
}

#let custom-heading-style(it) = {
  if it.level >= 2 {
    let daynote-num = daynote-counter.get().at(0)
    let heading-nums = counter(heading).get()
    let (numbering, body, ..args) = it.fields()
    
    let num-str = str(daynote-num) + "." + heading-nums.slice(1, it.level).map(str).join(".")
    
    let heading-text = num-str + " " + body
    heading-text

    if daynotes-to-show.len() == 0 or daynotes-to-show.contains(daynote-num){
      show heading: none
      heading(..args, outlined: false, bookmarked: true, numbering: none, heading-text)
    }
  } else {
    let (numbering, body, ..args) = it.fields()
    let daynote-num = daynote-counter.get().at(0)
    let numbered-body = block({
      body
    })
    body
    if daynotes-to-show.len() == 0 or daynotes-to-show.contains(daynote-num){
      show heading: none
      heading(..args, outlined: false, bookmarked: true, numbering: none, numbered-body)
    }
  } 
}

#let definition(..args) = thm-env("Definition", rgb("#daa4a4"), has-proof: false, ..args)
#let theorem(..args) = thm-env("Theorem", rgb("#4773da"), ..args)
#let lemma(..args) = thm-env("Lemma", rgb("#C8E2FF"), ..args)
#let proposition(..args) = thm-env("Proposition", rgb("#88bef4"), ..args)
#let corollary(..args) = thm-env("Corollary", rgb("#94d0b7"), ..args)
#let example(..args) = thm-env("Example", rgb("#7acb83"), has-proof: false, ..args)
#let remark(..args) = thm-env("Remark", rgb("#f4dc51"), has-proof: false, ..args)
#let caution(..args) = thm-env("Caution", rgb("#ec8484"), has-proof: false, ..args)

#let exercise(..args) = problem-env("Exercise", rgb("#d95b96"), ..args)
#let assignment(..args) = problem-env("Assignment", rgb("#ff7dbc"), visible: show-assignment, ..args)
#let quiz(..args) = problem-env("Quiz", rgb("#af40af"), visible: show-quiz, ..args)

#let hint(..args) = solution-env("Hint", rgb("#3a99ff"), is-proof: false, ..args)
#let proof(..args) = solution-env("Proof", rgb("#bfbdbd"), ..args)
