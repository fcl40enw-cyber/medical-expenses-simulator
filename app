/**
 * 在宅医療費用シミュレーター
 * 特定医療法人 新生病院
 */

class MedicalFeeCalculator {
    constructor() {
        this.form = document.getElementById('simulationForm');
        this.resultSection = document.getElementById('resultSection');
        this.loadingSpinner = document.getElementById('loadingSpinner');
        this.totalAmountDisplay = document.getElementById('totalAmount').querySelector('span');
        this.breakdownContainer = document.getElementById('breakdown');
        
        // 2024年度診療報酬改定正確な点数（点数×10円）
        this.medicalFees = {
            // 1. 在宅時医学総合管理料（月額）- 2024年度訪問回数・重症度別
            在総管: {
                '在総管1': {
                    monthly_1: 27450,      // 月1回: 2,745点 × 10円
                    monthly_2_normal: 44850, // 月2回以上（重症度なし）: 4,485点
                    monthly_2_severe: 53850, // 月2回以上（重症度あり）: 5,385点
                    description: '在宅時医学総合管理料（同一日に訪問する患者が1人）'
                },
                '在総管2-9': {
                    monthly_1: 14850,      // 月1回: 1,485点 × 10円
                    monthly_2_normal: 23850, // 月2回以上（重症度なし）: 2,385点
                    monthly_2_severe: 44850, // 月2回以上（重症度あり）: 4,485点
                    description: '在宅時医学総合管理料（同一日に訪問する患者が2-9人）'
                },
                '在総管10-19': {
                    monthly_1: 7650,       // 月1回: 765点 × 10円
                    monthly_2_normal: 11850, // 月2回以上（重症度なし）: 1,185点
                    monthly_2_severe: 28650, // 月2回以上（重症度あり）: 2,865点
                    description: '在宅時医学総合管理料（同一日に訪問する患者が10-19人）'
                }
            },
            // 施設入居時等医学総合管理料（月額）- 2024年度訪問回数・重症度別
            施設総管: {
                '施設総管1': {
                    monthly_1: 19650,      // 月1回: 1,965点 × 10円
                    normal: 31850,         // 月2回以上（重症度なし）: 3,185点
                    severe: 38850,         // 月2回以上（重症度あり）: 3,885点
                    description: '施設入居時等医学総合管理料（同一日に訪問する患者が1人）'
                },
                '施設総管2-9': {
                    monthly_1: 10650,      // 月1回: 1,065点 × 10円
                    normal: 16850,         // 月2回以上（重症度なし）: 1,685点
                    severe: 32250,         // 月2回以上（重症度あり）: 3,225点
                    description: '施設入居時等医学総合管理料（同一日に訪問する患者が2-9人）'
                },
                '施設総管10-19': {
                    monthly_1: 7650,       // 月1回: 765点 × 10円
                    normal: 11850,         // 月2回以上（重症度なし）: 1,185点
                    severe: 28650,         // 月2回以上（重症度あり）: 2,865点
                    description: '施設入居時等医学総合管理料（同一日に訪問する患者が10-19人）'
                }
            },
            // 在宅がん医療総合診療料（日額）
            在がん: {
                with_prescription: 17980,    // 1,798点 × 10円（処方せん交付あり）
                without_prescription: 20000, // 2,000点 × 10円（処方せん交付なし）
                description: '在宅がん医療総合診療料'
            }
        };
        
        // 2. 在宅患者訪問診療料（日額）
        this.visitFees = {
            single: 8880,     // 888点（同一日に1人のみ訪問）
            multiple: 2030    // 203点（同一日に2人以上訪問）
        };
        
        // 3. 介護保険（居宅療養管理指導）- 訪問患者数別料金表（2024年度正確単位）
        this.nursingFees = {
            // 医師による居宅療養管理指導
            doctor: {
                // 在宅がん医療総合診療料算定時
                '在がん': {
                    '1名': 5150,        // Ⅰ1: 515単位 × 10円（1人）
                    '2-9名': 4870,      // Ⅰ2: 487単位 × 10円（2-9人）
                    '10名以上': 4460    // Ⅰ3: 446単位 × 10円（10人以上）
                },
                // それ以外（在総管・施設総管算定時）
                'その他': {
                    '1名': 2990,        // Ⅱ1: 299単位 × 10円（1人）
                    '2-9名': 2870,      // Ⅱ2: 287単位 × 10円（2-9人）
                    '10名以上': 2600    // Ⅱ3: 260単位 × 10円（10人以上）
                }
            },
            // 薬剤師による居宅療養管理指導
            pharmacist: 4030           // 薬剤師: 403単位
        };

        // 交通費（自費・距離別料金表）
        this.distanceFees = [
            { min: 0, max: 4, fee: 0 },      // 4km未満: なし
            { min: 4, max: 6, fee: 509 },    // 4-6km: 509円
            { min: 6, max: 8, fee: 1019 },   // 6-8km: 1,019円
            { min: 8, max: Infinity, fee: 1528 }  // 8km以上: 1,528円
        ];

        this.initializeEventListeners();
    }

    initializeEventListeners() {
        this.form.addEventListener('submit', this.handleFormSubmit.bind(this));
        this.form.addEventListener('reset', this.handleFormReset.bind(this));
        
        // 印刷ボタンのイベントリスナー
        const printButton = document.getElementById('printButton');
        if (printButton) {
            printButton.addEventListener('click', this.handlePrint.bind(this));
        }
        
        // 患者タイプ変更時の表示制御
        const patientTypeSelect = document.getElementById('patientType');
        const prescriptionGroup = document.getElementById('prescriptionGroup');
        const prescriptionSelect = document.getElementById('prescription');
        const severityGroup = document.querySelector('[for="severity"]').closest('.form-group');
        const severitySelect = document.getElementById('severity');
        
        patientTypeSelect.addEventListener('change', (e) => {
            if (e.target.value === '在がん') {
                // 処方せん交付を表示
                prescriptionGroup.style.display = 'block';
                prescriptionSelect.required = true;
                
                // 重症度選択を非表示
                severityGroup.style.display = 'none';
                severitySelect.required = false;
                severitySelect.value = '重症度なし'; // デフォルト値を設定
            } else {
                // 処方せん交付を非表示
                prescriptionGroup.style.display = 'none';
                prescriptionSelect.required = false;
                prescriptionSelect.value = '';
                
                // 重症度選択を表示
                severityGroup.style.display = 'block';
                severitySelect.required = true;
                severitySelect.value = '';
            }
        });
    }

    handleFormSubmit(event) {
        event.preventDefault();
        
        if (!this.validateForm()) {
            // validateForm内でエラーメッセージが表示されるのでここでは何もしない
            return;
        }

        this.showLoading(true);
        
        // 非同期処理をシミュレート
        setTimeout(() => {
            try {
                const formData = this.getFormData();
                const calculationResult = this.calculateFee(formData);
                this.displayResult(calculationResult);
                this.saveSimulationResult(formData, calculationResult);
            } catch (error) {
                console.error('計算エラー:', error);
                this.showError('計算中にエラーが発生しました。');
            } finally {
                this.showLoading(false);
            }
        }, 1000);
    }

    handleFormReset() {
        this.resultSection.style.display = 'none';
        this.scrollToTop();
    }

    getFormData() {
        const formData = new FormData(this.form);
        
        return {
            patientType: formData.get('patientType') || '',
            insuranceRate: parseInt(formData.get('insuranceRate')) || 0,
            nursingRate: parseInt(formData.get('nursingRate')) || 0,
            incomeLevel: formData.get('incomeLevel') || '',
            distance: parseFloat(formData.get('distance')) || 0,
            nursingService: formData.get('nursingService') || '',
            prescription: formData.get('prescription') || '',
            monthlyVisits: parseInt(formData.get('monthlyVisits')) || 0,
            severity: formData.get('severity') || '',
            welfareSubsidy: formData.has('welfareSubsidy'),
            rareDisease: formData.has('rareDisease')
        };
    }

    calculateFee(data) {
        let calculation = {
            categories: {
                medical: { name: '1. 在総管と加算', items: [], subtotal: 0 },
                visit: { name: '2. 在宅患者訪問診療料と加算', items: [], subtotal: 0 },
                nursing: { name: '3. 介護保険（居宅療養管理指導）', items: [], subtotal: 0 },
                transport: { name: '4. 自費（交通費）', items: [], subtotal: 0 }
            },
            totalAfterInsurance: 0,
            patientType: data.patientType,
            severity: data.severity
        };

        // 1. 在総管または在がんの計算
        if (data.patientType === '在がん') {
            // 処方せん交付の有無で料金が変わる（1日あたり×30日で算定）
            const dailyFee = data.prescription === 'あり' ? 
                this.medicalFees.在がん.with_prescription : 
                this.medicalFees.在がん.without_prescription;
            const totalFee = dailyFee * 30; // 月30日固定
            
            calculation.categories.medical.items.push({
                name: '在宅がん医療総合診療料',
                detail: `${dailyFee}円 × 30日（処方せん交付${data.prescription}）`,
                amount: totalFee
            });
            calculation.categories.medical.subtotal = totalFee;
        } else if (data.patientType.includes('在総管') || data.patientType.includes('施設総管')) {
            const category = data.patientType.includes('在総管') ? '在総管' : '施設総管';
            const feeInfo = this.medicalFees[category][data.patientType];
            
            if (!feeInfo) {
                throw new Error(`料金情報が見つかりません: ${data.patientType}`);
            }
            
            let fee, feeDetail;
            
            if (category === '在総管') {
                // 在総管は訪問回数と重症度で料金が変わる
                if (data.monthlyVisits === 1) {
                    fee = feeInfo.monthly_1;
                    feeDetail = '月1回';
                } else {
                    // 月2回以上
                    if (data.severity === '重症度あり') {
                        fee = feeInfo.monthly_2_severe;
                        feeDetail = '月2回以上（重症度あり）';
                    } else {
                        fee = feeInfo.monthly_2_normal;
                        feeDetail = '月2回以上（重症度なし）';
                    }
                }
            } else {
                // 施設総管も訪問回数と重症度で判定
                if (data.monthlyVisits === 1) {
                    fee = feeInfo.monthly_1;
                    feeDetail = '月1回';
                } else {
                    // 月2回以上は重症度で判定
                    if (data.severity === '重症度あり') {
                        fee = feeInfo.severe;
                        feeDetail = '月2回以上（重症度あり）';
                    } else {
                        fee = feeInfo.normal;
                        feeDetail = '月2回以上（重症度なし）';
                    }
                }
            }
            
            calculation.categories.medical.items.push({
                name: feeInfo.description,
                detail: feeDetail,
                amount: fee
            });
            calculation.categories.medical.subtotal = fee;
        }

        // 2. 在宅患者訪問診療料の計算
        if (data.patientType !== '在がん') {
            const isMultiplePatients = data.patientType.includes('2-9') || data.patientType.includes('10-19');
            const visitFeePerDay = isMultiplePatients ? this.visitFees.multiple : this.visitFees.single;
            const totalVisitFee = visitFeePerDay * data.monthlyVisits;
            
            calculation.categories.visit.items.push({
                name: '在宅患者訪問診療料',
                detail: `${visitFeePerDay}円 × ${data.monthlyVisits}日`,
                amount: totalVisitFee
            });
            
            // 同日複数患者訪問加算
            if (isMultiplePatients) {
                calculation.categories.visit.items.push({
                    name: '同日複数患者訪問加算',
                    detail: '適用済み',
                    amount: 0
                });
            }
            
            calculation.categories.visit.subtotal = totalVisitFee;
        }

        // 3. 介護保険（居宅療養管理指導）
        // 介護保険サービス利用者には算定
        const isNursingServiceUser = this.isNursingInsuranceApplicable(data);
        
        if (isNursingServiceUser) {
            // 患者タイプから訪問患者数を判定
            let patientCount = '1名';
            if (data.patientType.includes('2-9') || data.patientType.includes('施設総管2-9')) {
                patientCount = '2-9名';
            } else if (data.patientType.includes('10-19') || data.patientType.includes('施設総管10-19')) {
                patientCount = '10名以上';
            }
            
            // 患者タイプに応じた料金区分を決定
            const feeCategory = data.patientType === '在がん' ? '在がん' : 'その他';
            const nursingFeePerVisit = this.nursingFees.doctor[feeCategory][patientCount];
            
            // 居宅療養管理指導は月2回まで算定可能
            const nursingVisits = Math.min(data.monthlyVisits, 2);
            const totalNursingFee = nursingFeePerVisit * nursingVisits;
            
            // 料金区分の表示名
            const categoryDisplayName = feeCategory === '在がん' ? 'Ⅰ' : 'Ⅱ';
            const patientNumSuffix = patientCount === '1名' ? '1' : (patientCount === '2-9名' ? '2' : '3');
            
            calculation.categories.nursing.items.push({
                name: `居宅療養管理指導（医師）`,
                detail: `${nursingFeePerVisit}円 × ${nursingVisits}回（${categoryDisplayName}${patientNumSuffix}・${patientCount}）`,
                amount: totalNursingFee
            });
            
            calculation.categories.nursing.subtotal = totalNursingFee;
        }

        // 4. 自費（交通費）
        const distanceFee = this.calculateDistanceFee(data.distance);
        if (distanceFee > 0) {
            const totalDistanceFee = distanceFee * data.monthlyVisits;
            
            calculation.categories.transport.items.push({
                name: '交通費',
                detail: `${distanceFee}円 × ${data.monthlyVisits}日`,
                amount: totalDistanceFee
            });
            
            calculation.categories.transport.subtotal = totalDistanceFee;
        }
        


        // 保険適用前合計
        calculation.totalBeforeInsurance = 
            calculation.categories.medical.subtotal +
            calculation.categories.visit.subtotal +
            calculation.categories.nursing.subtotal +
            calculation.categories.transport.subtotal;

        // 保険適用の計算
        // 1. 医療保険適用部分（在総管・訪問診療料）
        const medicalInsuranceCovered = 
            calculation.categories.medical.subtotal + 
            calculation.categories.visit.subtotal;
        let medicalPatientBurden = Math.ceil(medicalInsuranceCovered * (data.insuranceRate / 100));
        
        // 高額療養費制度の適用
        let hasHighCostLimit = false;
        let highCostLimit = 0;
        let originalMedicalBurden = medicalPatientBurden;
        
        if (medicalInsuranceCovered > 0 && data.incomeLevel && data.incomeLevel !== '') {
            highCostLimit = this.calculateHighCostMedicalLimit(medicalInsuranceCovered, data.incomeLevel);
            
            if (medicalPatientBurden > highCostLimit) {
                medicalPatientBurden = highCostLimit;
                hasHighCostLimit = true;
            }
        }
        
        // 70歳以上の医療費上限額適用（在宅がん患者の場合）- 高額療養費制度と併用
        let hasUpperLimit = false;
        const is70OrOlder = data.incomeLevel && (data.incomeLevel.startsWith('70-74歳_') || data.incomeLevel.startsWith('75歳～_'));
        if (data.patientType === '在がん' && is70OrOlder) {
            const upperLimit = 18000; // 18,000円
            if (medicalPatientBurden > upperLimit) {
                medicalPatientBurden = upperLimit;
                hasUpperLimit = true;
            }
        }
        
        // 2. 介護保険適用部分（居宅療養管理指導）
        const nursingInsuranceCovered = calculation.categories.nursing.subtotal;
        const nursingPatientBurden = (nursingInsuranceCovered > 0 && data.nursingRate > 0) ? 
            Math.ceil(nursingInsuranceCovered * (data.nursingRate / 100)) : nursingInsuranceCovered || 0;
        
        // 3. 全額自費部分（交通費）
        const selfPayAmount = calculation.categories.transport.subtotal;
        
        // 医療保険適用部分の各分野別自己負担算出
        const medicalRatio = medicalInsuranceCovered > 0 ? (medicalPatientBurden / medicalInsuranceCovered) : 0; // 自己負担率
        
        const medicalCategoryBurden = calculation.categories.medical.subtotal > 0 ? Math.ceil(calculation.categories.medical.subtotal * medicalRatio) : 0;
        const visitCategoryBurden = calculation.categories.visit.subtotal > 0 ? Math.ceil(calculation.categories.visit.subtotal * medicalRatio) : 0;
        
        // 各分野の保険適用情報を更新
        calculation.categories.medical.originalAmount = calculation.categories.medical.subtotal;
        calculation.categories.medical.patientBurden = medicalCategoryBurden;
        calculation.categories.medical.subtotal = medicalCategoryBurden;
        
        calculation.categories.visit.originalAmount = calculation.categories.visit.subtotal;
        calculation.categories.visit.patientBurden = visitCategoryBurden;
        calculation.categories.visit.subtotal = visitCategoryBurden;
        
        calculation.categories.nursing.originalAmount = calculation.categories.nursing.subtotal;
        calculation.categories.nursing.patientBurden = nursingPatientBurden;
        calculation.categories.nursing.subtotal = nursingPatientBurden;
        
        // 最終合計（保険適用後） - NaN防止
        calculation.totalBeforeInsurance = (medicalInsuranceCovered || 0) + (nursingInsuranceCovered || 0) + (selfPayAmount || 0);
        calculation.totalAfterInsurance = (medicalPatientBurden || 0) + (nursingPatientBurden || 0) + (selfPayAmount || 0);
        
        // 保険情報を追加
        calculation.insuranceInfo = {
            medicalRate: data.insuranceRate,
            nursingRate: data.nursingRate,
            medicalOriginal: medicalInsuranceCovered,
            medicalBurden: medicalPatientBurden,
            originalMedicalBurden: originalMedicalBurden,
            nursingOriginal: nursingInsuranceCovered,
            nursingBurden: nursingPatientBurden,
            selfPay: selfPayAmount,
            hasUpperLimit: hasUpperLimit,
            upperLimit: hasUpperLimit ? 18000 : null,
            hasHighCostLimit: hasHighCostLimit,
            highCostLimit: hasHighCostLimit ? highCostLimit : null,
            incomeLevel: data.incomeLevel || ''
        };

        return calculation;
    }

    calculateDistanceFee(distance) {
        const feeInfo = this.distanceFees.find(f => distance >= f.min && distance < f.max);
        return feeInfo ? feeInfo.fee : this.distanceFees[this.distanceFees.length - 1].fee;
    }




    calculateHighCostMedicalLimit(medicalCost, incomeLevel) {
        // 高額療養費制度の自己負担上限額計算
        let limit = 0;
        
        // 所得水準から年齢区分と所得区分を分離
        if (incomeLevel.startsWith('70-74歳_') || incomeLevel.startsWith('75歳～_')) {
            // 70歳以上（外来・入院合算）
            const incomePart = incomeLevel.split('_')[1];
            switch(incomePart) {
                case '現役並み所得Ⅲ':
                    limit = 252600 + Math.max(0, Math.floor((medicalCost - 842000) * 0.01));
                    break;
                case '現役並み所得Ⅱ':
                    limit = 167400 + Math.max(0, Math.floor((medicalCost - 558000) * 0.01));
                    break;
                case '現役並み所得Ⅰ':
                    limit = 80100 + Math.max(0, Math.floor((medicalCost - 267000) * 0.01));
                    break;
                case '一般':
                    limit = Math.min(57600, 14000 + Math.floor((medicalCost - 14000) * 0.1)); // 外来上限14,000円
                    break;
                case '低所得Ⅱ':
                    limit = 24600;
                    break;
                case '低所得Ⅰ':
                    limit = 15000;
                    break;
                default:
                    limit = Math.min(57600, 14000 + Math.floor((medicalCost - 14000) * 0.1));
            }
        } else {
            // 69歳以下（協会けんぽの区分）
            switch(incomeLevel) {
                case '年収約1,160万円～':
                    limit = 252600 + Math.max(0, Math.floor((medicalCost - 842000) * 0.01));
                    break;
                case '年収約770～1,160万円':
                    limit = 167400 + Math.max(0, Math.floor((medicalCost - 558000) * 0.01));
                    break;
                case '年収約370～770万円':
                    limit = 80100 + Math.max(0, Math.floor((medicalCost - 267000) * 0.01));
                    break;
                case '年収～370万円':
                    limit = 57600;
                    break;
                case '住民税非課税':
                    limit = 35400;
                    break;
                default:
                    limit = 80100 + Math.max(0, Math.floor((medicalCost - 267000) * 0.01));
            }
        }
        
        return Math.floor(limit);
    }
    
    isNursingInsuranceApplicable(data) {
        // 介護保険サービス利用が「あり」と選択された場合
        // これは以下の条件を満たす場合を想定：
        // 1. 75歳以上（第1号被保険者）
        // 2. 40歳以上で要介護認定を受けている（第2号被保険者）
        return data.nursingService === 'あり';
    }



    displayResult(calculation) {
        // 総額表示 - NaN防止
        const totalAmount = calculation.totalAfterInsurance || 0;
        this.totalAmountDisplay.textContent = isNaN(totalAmount) ? '0' : totalAmount.toLocaleString();
        
        // 内訳表示
        this.breakdownContainer.innerHTML = '';
        
        // 基本情報 - NaN防止
        const beforeInsuranceTotal = calculation.totalBeforeInsurance || 0;
        const medicalRate = calculation.insuranceInfo?.medicalRate || 0;
        const nursingRate = calculation.insuranceInfo?.nursingRate || 0;
        
        const infoDiv = document.createElement('div');
        infoDiv.className = 'result-info';
        infoDiv.innerHTML = `
            <h4>患者タイプ: ${calculation.patientType || ''}</h4>
            ${calculation.severity ? `<p>重症度: ${calculation.severity}</p>` : ''}
            <p>医療保険負担割合: ${medicalRate}%</p>
            <p>介護保険負担割合: ${nursingRate}%</p>
            <p>保険適用前合計: ¥${isNaN(beforeInsuranceTotal) ? '0' : beforeInsuranceTotal.toLocaleString()}</p>
        `;
        this.breakdownContainer.appendChild(infoDiv);

        // 4分野別料金表示
        Object.values(calculation.categories).forEach(category => {
            if ((category.originalAmount && category.originalAmount > 0) || category.subtotal > 0 || category.items.length > 0) {
                // カテゴリーヘッダー
                const categoryHeader = document.createElement('div');
                categoryHeader.className = 'category-header';
                
                let headerContent = `<h5>${category.name || ''}</h5>`;
                const originalAmount = category.originalAmount || 0;
                const subtotal = category.subtotal || 0;
                
                if (originalAmount > 0) {
                    // 保険適用ありの場合
                    headerContent += `<div class="insurance-info">`;
                    headerContent += `<small>保険適用前: ¥${isNaN(originalAmount) ? '0' : originalAmount.toLocaleString()}</small>`;
                    headerContent += `<span class="category-total">自己負担: ¥${isNaN(subtotal) ? '0' : subtotal.toLocaleString()}</span>`;
                    headerContent += `</div>`;
                } else {
                    // 保険適用なし（自費）
                    headerContent += `<span class="category-total">¥${isNaN(subtotal) ? '0' : subtotal.toLocaleString()}</span>`;
                }
                
                categoryHeader.innerHTML = headerContent;
                this.breakdownContainer.appendChild(categoryHeader);
                
                // カテゴリー内訳
                category.items.forEach(item => {
                    const itemDiv = document.createElement('div');
                    itemDiv.className = 'breakdown-item category-item';
                    
                    const itemAmount = item.amount || 0;
                    itemDiv.innerHTML = `
                        <div class="breakdown-name">
                            <strong>${item.name || ''}</strong>
                            <small>${item.detail || ''}</small>
                        </div>
                        <div class="breakdown-amount">
                            ¥${isNaN(itemAmount) ? '0' : itemAmount.toLocaleString()}
                        </div>
                    `;
                    this.breakdownContainer.appendChild(itemDiv);
                });
            }
        });
        


        // 保険適用情報の表示 - NaN防止
        if (calculation.insuranceInfo) {
            const info = calculation.insuranceInfo;
            const medicalOriginal = info.medicalOriginal || 0;
            const medicalBurden = info.medicalBurden || 0;
            const nursingOriginal = info.nursingOriginal || 0;
            const nursingBurden = info.nursingBurden || 0;
            const selfPay = info.selfPay || 0;
            const medicalRate = info.medicalRate || 0;
            const nursingRate = info.nursingRate || 0;
            
            const insuranceDiv = document.createElement('div');
            insuranceDiv.className = 'insurance-summary';
            insuranceDiv.innerHTML = `
                <h5>保険適用結果</h5>
                <div class="insurance-breakdown">
                    <div class="insurance-item">
                        <span>医療保険適用部分（在総管+訪問診療料）:</span>
                        <span>¥${isNaN(medicalOriginal) ? '0' : medicalOriginal.toLocaleString()} → ¥${isNaN(medicalBurden) ? '0' : medicalBurden.toLocaleString()} (${medicalRate}%負担${info.hasHighCostLimit || info.hasUpperLimit ? '・上限額適用' : ''})</span>
                    </div>
                    ${info.hasHighCostLimit ? `
                        <div class="insurance-item highlight">
                            <span>🏥 高額療養費制度適用:</span>
                            <span>¥${isNaN(info.originalMedicalBurden) ? '0' : info.originalMedicalBurden.toLocaleString()} → ¥${isNaN(info.highCostLimit) ? '0' : info.highCostLimit.toLocaleString()}（${info.incomeLevel}）</span>
                        </div>` : ''}
                    ${info.hasUpperLimit ? `<div class="insurance-item"><span>70歳以上医療費上限額:</span><span>¥18,000（上限額適用済み）</span></div>` : ''}
                    <div class="insurance-item">
                        <span>介護保険適用部分:</span>
                        <span>${nursingOriginal > 0 ? 
                            `¥${isNaN(nursingOriginal) ? '0' : nursingOriginal.toLocaleString()} → ¥${isNaN(nursingBurden) ? '0' : nursingBurden.toLocaleString()} (${nursingRate}%負担)` : 
                            '適用なし（サービス利用なし）'
                        }</span>
                    </div>
                    <div class="insurance-item">
                        <span>自費部分（交通費）:</span>
                        <span>¥${isNaN(selfPay) ? '0' : selfPay.toLocaleString()}</span>
                    </div>
                </div>
            `;
            this.breakdownContainer.appendChild(insuranceDiv);
        }
        
        // 最終合計 - NaN防止
        const finalTotal = calculation.totalAfterInsurance || 0;
        const totalDiv = document.createElement('div');
        totalDiv.className = 'breakdown-item total';
        totalDiv.innerHTML = `
            <div class="breakdown-name">
                <strong>月額自己負担額</strong>
                <small>保険適用後の合計額</small>
            </div>
            <div class="breakdown-amount">
                ¥${isNaN(finalTotal) ? '0' : finalTotal.toLocaleString()}
            </div>
        `;
        this.breakdownContainer.appendChild(totalDiv);

        // 結果表示
        this.resultSection.style.display = 'block';
        this.scrollToResult();
    }

    async saveSimulationResult(formData, calculation) {
        try {
            const resultData = {
                ...formData,
                monthly_fee: calculation.totalAfterInsurance,
                breakdown: JSON.stringify(calculation),
                simulation_date: Date.now()
            };

            const response = await fetch('tables/simulation_results', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(resultData)
            });

            if (!response.ok) {
                console.warn('シミュレーション結果の保存に失敗しました');
            }
        } catch (error) {
            console.warn('シミュレーション結果保存エラー:', error);
        }
    }

    validateForm() {
        const requiredFields = [
            { name: 'patientType', label: '患者タイプ' },
            { name: 'insuranceRate', label: '医療保険負担割合' },
            { name: 'nursingRate', label: '介護保険負担割合' },
            { name: 'nursingService', label: '介護保険サービス利用' },
            { name: 'incomeLevel', label: '所得水準' },
            { name: 'distance', label: '距離' },
            { name: 'monthlyVisits', label: '月間訪問日数' },
            { name: 'severity', label: '重症度' }
        ];
        
        const missingFields = [];
        
        for (const field of requiredFields) {
            const element = this.form.querySelector(`[name="${field.name}"]`);
            if (!element || !element.value.trim()) {
                missingFields.push(field.label);
            }
        }
        
        // 在宅がん医療総合診療料の場合は処方せん交付が必須
        const patientTypeElement = this.form.querySelector('[name="patientType"]');
        const prescriptionElement = this.form.querySelector('[name="prescription"]');
        if (patientTypeElement && patientTypeElement.value === '在がん') {
            if (!prescriptionElement || !prescriptionElement.value.trim()) {
                missingFields.push('処方せん交付');
            }
        }
        
        if (missingFields.length > 0) {
            const message = `以下の項目を入力してください：\n\n${missingFields.map(field => `・ ${field}`).join('\n')}`;
            this.showError(message);
            return false;
        }
        
        return true;
    }

    showLoading(show) {
        this.loadingSpinner.style.display = show ? 'flex' : 'none';
    }

    showError(message) {
        alert(message); // より良いエラー表示を後で実装可能
    }

    scrollToResult() {
        this.resultSection.scrollIntoView({ 
            behavior: 'smooth',
            block: 'start'
        });
    }

    scrollToTop() {
        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    }

    handlePrint() {
        // 印刷用のデータを準備
        const printData = this.preparePrintData();
        if (!printData) {
            this.showError('印刷するデータがありません。先に料金計算を行ってください。');
            return;
        }

        // 印刷用ウィンドウを開く
        const printWindow = window.open('', '_blank');
        const printContent = this.generatePrintContent(printData);
        
        printWindow.document.write(printContent);
        printWindow.document.close();
        
        // 印刷ダイアログを表示
        printWindow.onload = () => {
            printWindow.print();
            // 印刷完了後にウィンドウを閉じる
            printWindow.onafterprint = () => {
                printWindow.close();
            };
        };
    }

    preparePrintData() {
        // 現在の計算結果があるかチェック
        if (this.resultSection.style.display === 'none') {
            return null;
        }

        // フォームデータを取得
        const formData = this.getFormData();
        
        // 計算結果の要素から情報を抽出
        const totalAmount = this.totalAmountDisplay.textContent;
        const breakdown = this.breakdownContainer.innerHTML;
        
        return {
            formData: formData,
            totalAmount: totalAmount,
            breakdown: breakdown,
            calculationDate: new Date().toLocaleString('ja-JP')
        };
    }

    generatePrintContent(data) {
        const { formData, totalAmount, breakdown, calculationDate } = data;
        
        return `
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>在宅医療費用計算結果 - 新生病院</title>
    <style>
        /* 印刷用CSS - A4用紙1枚対応 */
        @page {
            size: A4;
            margin: 12mm 15mm;
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Noto Sans JP', 'Hiragino Sans', 'ヒラギノ角ゴシック', sans-serif;
            font-size: 9pt;
            line-height: 1.2;
            color: #333;
            background: white;
        }
        
        .print-header {
            text-align: center;
            border-bottom: 2px solid #4CAF50;
            padding-bottom: 6pt;
            margin-bottom: 8pt;
        }
        
        .print-header h1 {
            font-size: 14pt;
            color: #2c3e50;
            margin-bottom: 2pt;
        }
        
        .print-header p {
            font-size: 10pt;
            color: #666;
        }
        
        .calculation-info {
            margin-bottom: 8pt;
            padding: 5pt;
            background: #f8f9fa;
            border-left: 3px solid #4CAF50;
        }
        
        .calculation-info h2 {
            font-size: 11pt;
            margin-bottom: 4pt;
            color: #2c3e50;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 6pt;
            font-size: 8pt;
        }
        
        .info-item {
            display: flex;
            justify-content: space-between;
            padding: 1pt 0;
            border-bottom: 1px dotted #ccc;
        }
        
        .info-item strong {
            color: #333;
        }
        
        .total-amount {
            text-align: center;
            margin: 8pt 0;
            padding: 8pt;
            background: #e8f5e8;
            border-radius: 4pt;
        }
        
        .total-amount h2 {
            font-size: 12pt;
            color: #2c3e50;
            margin-bottom: 4pt;
        }
        
        .total-amount .amount {
            font-size: 18pt;
            font-weight: bold;
            color: #4CAF50;
        }
        
        .breakdown-section {
            margin: 6pt 0;
        }
        
        .breakdown-section h3 {
            font-size: 10pt;
            color: #2c3e50;
            margin-bottom: 4pt;
            border-bottom: 1px solid #ddd;
            padding-bottom: 2pt;
        }
        
        /* 内訳表示の調整 - コンパクト化 */
        .result-info,
        .category-header,
        .breakdown-item,
        .insurance-summary {
            margin-bottom: 3pt !important;
            padding: 3pt !important;
            border-radius: 2pt !important;
            font-size: 8pt !important;
            line-height: 1.1 !important;
        }
        
        .category-header {
            background: #f0f8ff !important;
            border-left: 2px solid #007bff !important;
            font-weight: bold;
        }
        
        .category-header h5 {
            font-size: 9pt !important;
            margin: 0 !important;
        }
        
        .breakdown-item {
            background: #fdfdfd !important;
            border-left: 1px solid #e9ecef !important;
            display: flex !important;
            justify-content: space-between !important;
            align-items: flex-start !important;
        }
        
        .breakdown-name {
            flex: 1;
            margin-right: 8pt;
        }
        
        .breakdown-name strong {
            font-size: 8pt !important;
            display: block;
        }
        
        .breakdown-name small {
            font-size: 7pt !important;
            color: #666 !important;
            display: block;
            margin-top: 1pt;
        }
        
        .breakdown-amount {
            text-align: right;
            font-weight: bold;
            white-space: nowrap;
        }
        
        .insurance-summary {
            background: #e8f4fd !important;
            border-left: 2px solid #007bff !important;
        }
        
        .insurance-summary h5 {
            font-size: 9pt !important;
            margin: 0 0 2pt 0 !important;
        }
        
        .insurance-breakdown {
            display: flex !important;
            flex-direction: column !important;
            gap: 1pt !important;
        }
        
        .insurance-item {
            display: flex !important;
            justify-content: space-between !important;
            align-items: center !important;
            font-size: 7pt !important;
            padding: 1pt 0 !important;
        }
        
        .insurance-item.highlight {
            background: #fff3cd !important;
            border: 1px solid #ffeaa7 !important;
            padding: 2pt !important;
            margin: 1pt 0 !important;
            border-radius: 2pt !important;
        }
        
        .insurance-item span:first-child {
            font-weight: 500;
            color: #495057;
            flex: 1;
            margin-right: 4pt;
        }
        
        .insurance-item span:last-child {
            font-weight: 600;
            color: #007bff;
            text-align: right;
            white-space: nowrap;
        }
        
        .disclaimer {
            margin-top: 8pt;
            padding: 4pt;
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 2pt;
            font-size: 7pt;
            line-height: 1.2;
        }
        
        .print-footer {
            position: fixed;
            bottom: 8mm;
            left: 0;
            right: 0;
            text-align: center;
            font-size: 7pt;
            color: #666;
            border-top: 1px solid #ccc;
            padding-top: 3pt;
        }
        
        /* 印刷時のスタイル調整 */
        @media print {
            body {
                -webkit-print-color-adjust: exact;
                color-adjust: exact;
            }
            
            .page-break {
                page-break-before: always;
            }
            
            h1, h2, h3 {
                page-break-after: avoid;
            }
            
            .breakdown-item {
                page-break-inside: avoid;
            }
        }
    </style>
</head>
<body>
    <div class="print-header">
        <h1>在宅医療費用計算結果</h1>
        <p>特定医療法人　新生病院</p>
    </div>
    
    <div class="calculation-info">
        <h2>計算条件</h2>
        <div class="info-grid">
            <div class="info-item">
                <span>患者タイプ:</span>
                <strong>${formData.patientType || '未設定'}</strong>
            </div>
            <div class="info-item">
                <span>所得水準:</span>
                <strong>${formData.incomeLevel || '未設定'}</strong>
            </div>
            <div class="info-item">
                <span>医療保険負担割合:</span>
                <strong>${formData.insuranceRate || 0}割負担</strong>
            </div>
            <div class="info-item">
                <span>介護保険負担割合:</span>
                <strong>${formData.nursingRate || 0}割負担</strong>
            </div>
            <div class="info-item">
                <span>月間訪問日数:</span>
                <strong>${formData.monthlyVisits || 0}日</strong>
            </div>
            <div class="info-item">
                <span>距離:</span>
                <strong>${formData.distance || 0}km</strong>
            </div>
            ${formData.severity ? `
            <div class="info-item">
                <span>重症度:</span>
                <strong>${formData.severity}</strong>
            </div>` : ''}
            ${formData.prescription ? `
            <div class="info-item">
                <span>処方せん交付:</span>
                <strong>${formData.prescription}</strong>
            </div>` : ''}
        </div>
    </div>
    
    <div class="total-amount">
        <h2>月額自己負担額</h2>
        <div class="amount">¥${totalAmount}</div>
    </div>
    
    <div class="breakdown-section">
        <h3>計算内訳</h3>
        <div class="breakdown-content">
            ${breakdown}
        </div>
    </div>
    
    <div class="disclaimer">
        <strong>ご注意：</strong>この料金は2024年度診療報酬改定に基づく概算です。実際の料金は個別の診療内容や保険適用状況により変動する場合があります。詳細については新生病院までお問い合わせください。
    </div>
    
    <div class="print-footer">
        計算日時: ${calculationDate} | 特定医療法人　新生病院　在宅医療費用シミュレーター
    </div>
</body>
</html>`;
    }
}

// アプリケーション初期化
document.addEventListener('DOMContentLoaded', () => {
    new MedicalFeeCalculator();
});

// エクスポート（テスト用）
if (typeof module !== 'undefined' && module.exports) {
    module.exports = MedicalFeeCalculator;
}
