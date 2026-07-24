.\load-env.ps1

.\generate_jobs.ps1 --input-dir .\models\L1\ --output-file jobs_L1.yml --with-plus
.\generate_jobs.ps1 --input-dir .\models\L2\ --output-file jobs_L2.yml
.\generate_jobs.ps1 --input-dir .\models\L3\ --output-file jobs_L3.yml

Copy-Item jobs_L1.yml jobs.yml
Get-Content jobs_L2.yml | Select-Object -Skip 19 | Add-Content jobs.yml
Get-Content jobs_L3.yml | Select-Object -Skip 19 | Add-Content jobs.yml

Remove-Item jobs_L1.yml, jobs_L2.yml, jobs_L3.yml

$env:PYTHONIOENCODING = 'utf-8'
dbt-jobs-as-code.exe plan --disable-ssl-verification jobs.yml | Tee-Object -FilePath plan_output.txt
