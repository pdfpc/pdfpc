install(FILES
    pdfpcrc
DESTINATION
    ${CMAKE_INSTALL_FULL_SYSCONFDIR}
)

install(FILES
    pdfpc.css notes.css
DESTINATION
    ${CMAKE_INSTALL_PREFIX}/share/pixmaps/pdfpc/
)
