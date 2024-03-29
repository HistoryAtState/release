xquery version "3.0";

import module namespace release = "http://history.state.gov/ns/xquery/release" at "modules/release.xql";
import module namespace epub = "http://history.state.gov/ns/xquery/epub" at "modules/epub.xql";
import module namespace frus = "http://history.state.gov/ns/xquery/frus" at "modules/frus.xql";

import module namespace console="http://exist-db.org/xquery/console";
import module namespace process="http://exist-db.org/xquery/process" at "java:org.exist.xquery.modules.process.ProcessModule";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html";
declare option output:media-type "text/html";

declare function local:output-directory() {
    let $username := environment-variable('USER')
    let $destination-folder-name := concat('frus-ebooks-', substring(xs:string(current-date()), 1, 10))
    return
        (: Assumes eXist is running under a macOS user account :)
        if ($username ne "") then
            concat('/Users/', $username, '/Downloads/', $destination-folder-name, '/')
        (: Assumes eXist is running within Docker, and the /tmp/hsg-project-downloads folder is mounted and accessible by the user :)
        else
            concat('/tmp/hsg-project-downloads/', $destination-folder-name, '/')
};

declare function local:generate-mobis() {
    let $log := console:log('starting conversion of mobi-bound epubs to mobi by calling calibre ebook-convert script')
    let $start-time := util:system-time()
    let $script := '# enter the source directory

cd mobi-bound;

# and fire off the conversion

find . -type f -iname "*.epub" | /usr/local/bin/parallel --timeout 14400 --progress "/Applications/calibre.app/Contents/MacOS/ebook-convert {} {.}.mobi";

# move the mobis into the mobi directory

mv *.mobi ../mobi/;'

    let $save-script := file:serialize-binary(util:string-to-binary($script), <x>{local:output-directory()}/convert-mobis.sh</x>)
    let $options :=
        <option>
            <workingDir>{local:output-directory()}</workingDir>
        </option>
    let $execute := try { process:execute(("sh", "./convert-mobis.sh"), $options) } catch * { <error>Error {$err:code} raised when running convert-mobis.sh: {$err:description}</error> }
    let $log := console:log('finished calibre ebook-convert script')
    let $end-time := util:system-time()
    let $duration := $end-time - $start-time
    let $minutes := minutes-from-duration($duration)
    let $seconds := seconds-from-duration($duration)
    return
        if ($execute instance of element(execution)) then
            if ($execute/@exitCode eq "0") then
                (
                    <p class="bg-success">{
                        concat('Completed conversion of mobi-bound epub(s) in ', if ($minutes gt 0) then concat($minutes, ' minutes, ') else (), $seconds, ' seconds.')
                    }</p>,
                    <pre>{
                        let $output := $execute/stdout/line
                        let $newline := '&#10;'
                        return
                            string-join($output, $newline)
                    }</pre>
                )
            else
                (
                    <p class="bg-danger">{
                        concat('Conversion of mobi-bound epub(s) to mobi failed after ', if ($minutes gt 0) then concat($minutes, ' minutes, ') else (), $seconds, ' seconds.')
                    }</p>,
                    <pre>{
                        let $output := $execute/stdout/line
                        let $newline := '&#10;'
                        return
                            string-join($output, $newline)
                    }</pre>
                )
        else (: if ($execute instance of element(error)) :)
            <p class="bg-danger">{$execute/string()}</p>
};

declare function local:generate-ebooks($vol-ids, $format) {
    for $vol in $vol-ids
    let $start-time := util:system-time()
    let $log := console:log(concat('starting ', $vol))
    let $tei-content-data-path := concat('/db/apps/frus/volumes/', $vol, '.xml')
    let $file-system-output-dir := local:output-directory()
    let $formats := if ($format = 'all') then ('mobi-bound', 'epub') else $format
    let $mkdirs := 
        (
            $file-system-output-dir, 
            ('epub', 'mobi', 'mobi-bound') ! ($file-system-output-dir || .)
        ) ! file:mkdirs(.)
    return
        for $f in $formats
        let $label := $local:ebook-format-options//item[value = $f]/label/string()
        let $log := console:log(concat('Starting ', $f, ' for ', $vol))
        return
            try {
                let $operation :=
                    if ($f = 'epub') then
                        epub:save-frus-epub-to-disk($tei-content-data-path, (), $file-system-output-dir)
                    else (: if ($f = 'mobi') then :)
                        epub:save-frus-epub-to-disk($tei-content-data-path, 'mobi', $file-system-output-dir)
                let $end-time := util:system-time()
                let $duration := $end-time - $start-time
                let $minutes := minutes-from-duration($duration)
                let $seconds := seconds-from-duration($duration)
                let $result := concat('Completed ', $label, ' version of ', $vol, ' in ', if ($minutes gt 0) then concat($minutes, ' minutes, ') else (), $seconds, ' seconds.')
                return
                    (
                    console:log($result),
                    <p class="bg-success">{$result}</p>
                    )
            } catch * {
                let $error := concat('Error while generating ', $f, ' version of vol ', $vol, ': ',
                        $err:code, $err:value, " module: ",
                        $err:module, "(", $err:line-number, ",", $err:column-number, ") ", $err:description
                        )
                return
                    (
                    console:log($error),
                    <p class="bg-danger">{$error}</p>
                    )
            }
};

declare variable $local:ebook-format-options :=
    <code-table>
        <items>
            <item>
                <value>epub</value>
                <label>EPUB</label>
            </item>
            <item>
                <value>mobi-bound</value>
                <label>Mobi-bound EPUB</label>
            </item>
            <item>
                <value>all</value>
                <label>Both</label>
            </item>
        </items>
    </code-table>
;

declare function local:form($volumes as xs:string*, $format as xs:string) {
    <form action="{request:get-url()}">
        <div class="form-group">
            <label for="volumes" class="control-label">Volume IDs</label>
            <div>
                <textarea name="volumes" id="volumes" class="form-control" rows="6">{$volumes}</textarea>
            </div>
        </div>
        <div class="form-group">
            <label class="control-label">Ebook formats</label>
            <div>{
                for $item in $local:ebook-format-options//item
                let $checked := if ($item/value = $format) then attribute checked {'checked'} else ()
                return
                    <label class="radio-inline">
                        <input type="radio" name="format" value="{$item/value}" />{$checked}
                        {$item/label/string()}
                    </label>
            }</div>
        </div>
        <div class="form-group">
            <button type="submit" class="btn btn-default">Generate Ebooks</button>
            <a class="btn btn-default" href="{request:get-url()}" role="button">Clear</a>
        </div>
    </form>
};

declare function local:validate($vol-ids as xs:string*) {
    for $vol-id in $vol-ids
    return
        if (frus:exists-volume-in-db($vol-id)) then ()
        else $vol-id
};

let $titles := ('Release', 'Ebook Batch Helper')
let $new-volumes := request:get-parameter('volumes', ())
let $format := request:get-parameter('format', 'all')
let $output-directory := local:output-directory()
let $body :=
    <div>
        <h2>{$titles[2]}</h2>
        {
            if (exists($new-volumes)) then
                (
                local:form($new-volumes, $format)
                ,
                let $vol-ids :=
                    for $vol-id in tokenize($new-volumes, '\s+')[. ne '']
                    order by $vol-id
                    return $vol-id
                let $invalid-ids := local:validate($vol-ids)
                return
                    if (empty($invalid-ids)) then
                        (
                        <div>
                            <h2>Results of {$local:ebook-format-options//item[value = $format]/label/string()} conversion</h2>
                            {local:generate-ebooks($vol-ids, $format)}
                        </div>
                        ,
                        if ($format = ('mobi-bound', 'all')) then
                            <div>
                                <h2>Results of {$local:ebook-format-options//item[value = 'mobi-bound']/label/string()} to Mobi conversion (via Calibre)</h2>
                                {local:generate-mobis()}
                            </div>
                        else
                            ()
                        )
                    else
                        <div class="bg-danger">
                            <p>The following volume ID(s) are invalid. Please correct the following and resubmit.</p>
                            <ul>{
                                for $vol-id in $invalid-ids
                                return
                                    <li>{$vol-id}</li>
                            }</ul>
                        </div>
                )
            else
                (
                local:form((), $format),
                <p>Please enter volume IDs, one per line. (Click <a href="?volumes=frus1969-76v18&amp;format=epub">here</a> to try generating frus1969-76v18 as an epub.)</p>,
                <p>Before generating Mobi-bound EPUBs, make sure you have installed <a href="https://calibre-ebook.com/download">Calibre</a>.</p>,
                <p>Generating an ebook can take as much as 5-10 minutes each (or even longer for volumes with page-number-based back-of-book indexes). Open the Monex <a href="/exist/apps/monex/console.html">Console</a> to follow status updates. If an ebook job is taking too long to generate, you can kill the entire query via the Monex <a href="/apps/monex/index.html">Monitoring</a> tab, under "Running Queries."</p>,
                <p>Ebooks are saved on your hard disk at: <code>{$output-directory}</code>.</p>
                )
        }
    </div>
return
    release:wrap-html($titles, $body)
