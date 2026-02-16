#import "env.typ": *
#import "utils.typ": *

#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

#set page(margin: .5in, numbering: "1")
#set text(font:"Calibri", size: 12pt)
#set par(justify: true)
#set list(indent: 1em, tight: false, spacing: 1em)
#set enum(indent: 1em, numbering: "1.a.i.", tight: false, spacing: 1em)

#set heading(numbering: "1.", bookmarked: false)

// Makes equations break accross pages
#show math.equation: set block(breakable: true)

// Makes reference colored
#show ref: it => text(fill: blue, it)

// Makes list item full width.
// https://forum.typst.app/t/how-to-make-justified-list-items-fill-the-entire-width/6168/3
#show list.item: it => {
  let children = it.body.at("children", default: ())
  if children.at(-1, default: none) == h(1fr) { return it }
  list.item(it.body + h(1fr))
}

#show heading: custom-heading-style

#daynote-title()

#daynote(
  date: datetime(year: 2025, month: 8, day: 12),
  tags: "important stuff"
)[
  Here goes stuff!

  #theorem("Theorem about stuff")[
    $x="stuff"$ implies something.
  ]

  #assignment("Solve stuff", "10", "assignment-solve-stuff")[
    Let $X$ be some stuff. Show some other stuff.
  ]
  
]


#context[#metadata(problems-label.final()) #label("problems-state")]

#show-all-quizzes()
