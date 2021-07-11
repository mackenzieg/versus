pragma solidity >=0.5.0;

interface PresaleToken {
    event PreparePresale();
    event PrepareLaunch();

    function preparePresale();
    function prepareLaunch();
}
