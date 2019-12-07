install(FILES pdfpc.sty
        DESTINATION ${CMAKE_INSTALL_PREFIX}/share/texmf/tex/latex/pdfpc
)
install(CODE "execute_process(COMMAND ${MKTEXLSR})"
)
