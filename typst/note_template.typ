#import "env.typ": *
#import "utils.typ": *

#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

#set page(margin: .5in, numbering: "1")
#set text(font:"Calibri", size: 12pt)
#set par(justify: true)

#set heading(numbering: "1.", bookmarked: false)
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
