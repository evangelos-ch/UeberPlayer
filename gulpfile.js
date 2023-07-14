const { src, dest, watch, series, lastRun } = require("gulp");
const zip = require("gulp-zip");
const path = require("path");
const { exec } = require("child_process");

const widgetLocation = `${process.env.HOME}/Library/Application Support/Übersicht/widgets`;

const buildNowPlayingCli = () =>
    exec(
        `git clone https://github.com/kirtan-shah/nowplaying-cli\
         && cd nowplaying-cli && git checkout 4cea032\
         && make && mv nowplaying-cli ../UeberPlayer.widget/lib/\
         && cd .. && rm -rf nowplaying-cli`
    );

const buildDist = () =>
    src("./UeberPlayer.widget/**/*", { since: lastRun(buildDist) }).pipe(dest("./dist/UeberPlayer.widget"));

const build = series(buildNowPlayingCli, buildDist);

const makeZip = () => src("./UeberPlayer.widget/**").pipe(zip("UeberPlayer.widget.zip")).pipe(dest("./"));

const apply = () => build().pipe(dest(path.join(widgetLocation, "UeberPlayer.widget")));

const dev = () => {
    watch("./UeberPlayer.widget/**/*", { ignoreInitial: false }, apply);
};

exports.default = build;
exports.apply = apply;
exports.dev = dev;
exports.release = series(build, makeZip);
